
require 'uri'
require 'net/http'
require './config'

$bearerToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZW5hbnQiOiJkNjdmOGZhNS01MTNmLTNmOTgtYTEzZC01NDdiOTgzYTU1ZmIiLCJhY2NvdW50SWQiOiI1ZDM4MzNmNDZlNTUzNzBiYzMwOGU3YTkiLCJpYXQiOjE1ODUzNDAyODcsImV4cCI6MTU4NTQyNjY4NywiYXVkIjoiMTk0NTZENzhFQ0Q3NDI0M0EyQjc5RjNFNUE5MEQwRTEiLCJpc3MiOiJjb20ueHBhbmRpdC5wbHVnaW5zLnhyYXkiLCJzdWIiOiIxOTQ1NkQ3OEVDRDc0MjQzQTJCNzlGM0U1QTkwRDBFMSJ9.KdmQrq7qz_chNtHZQwQCrWO1IhGv2zOI_3zXBu2c7yc';

def xrayGetBearerToken()
    url = URI($config[:xrayAuthUrl])

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(url)
    request["content-type"] = 'application/json'
    request.body = "{ \"client_id\": \"#{$config[:xrayClientId]}\",
                      \"client_secret\": \"#{$config[:xrayClientSecret]}\" }"

    response = http.request(request)

    $bearerToken = response.read_body.gsub('"', '')
end

def xrayGetSuite(testSetId)
    url = URI($config[:xrayGraphqlUrl])

    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Get.new(url)
    request["content-type"] = 'application/json'
    request["authorization"] = "Bearer #{$bearerToken}"

    body = <<EOM
    {
        getTestSet(issueId: "#{testSetId}")
            {
                issueId
                jira (fields: ["key", "summary"])
                tests(limit: 100)
                {
                    results {
                        issueId
                        preconditions (limit: 1) {
                            results {
                                issueId
                            }
                        }
                        testExecutions (limit: 1) {
                            results {
                                issueId
                                jira (fields: ["key"])
                            }
                        }
                        testRuns (limit: 5) {
                            results {
                                status {name}
                            }
                        }
                        testPlans(limit: 5  ) {
                            results {
                              issueId
                              jira(fields: ["key"])
                            }
                        }
                    jira (fields: ["key", "summary", "labels"])
                    testType {name}
                }
            }
        }
    }
EOM

    body = '{"query":"' + body.gsub("\n", ' ').gsub('"', '\\"').squeeze(' ') + '"}'

    request.body = body;

    response = http.request(request)
    hResponse=JSON.parse(response.read_body)

    return {
        'key' => hResponse['data']['getTestSet']['jira']['key'],
        'summary' => hResponse['data']['getTestSet']['jira']['summary'],
        'tests' => hResponse['data']['getTestSet']['tests']['results']
    }
end

def xrayTestSetContainsTests?(testSet)
    return testSet['tests'].count
end

def xrayTestsContainLabel?(arrTests, jiraIssueKey)
    allTestsAllLabels = []

    arrTests.each { |hTest|
        labels = hTest['jira']['labels']
        testKey = hTest['jira']['key']

        if !labels.include? jiraIssueKey
            put_r "\tTest #{testKey} has no label '#{jiraIssueKey}'"
            exit
        else
            allTestsAllLabels = allTestsAllLabels | labels
        end
    }

    return allTestsAllLabels
end

def xrayCreateExecutionAndAddTests(suiteName, arrTests)
    arrExecutions = []
    nTestsContainedInExection = 0

    arrTests.each { |hTest|
        testKey = hTest['jira']['key']
        testName = hTest['jira']['summary']

        nTestsContainedInExection += 1 if hTest['testExecutions']['results'].count > 0
        arrExecutions = arrExecutions | hTest['testExecutions']['results']
    }

    arrTestIds = arrTests.map { |test| test['issueId']}

    if (nTestsContainedInExection == 0)
        if (yesno("Create execution and add tests to it?", true))
            executionId = xrayCreateExecution(suiteName)
            xrayAddTestsToExecution(executionId, arrTestIds)
        end
    elsif (arrExecutions.count < arrTests.count and arrExecutions.count == 1 and nTestsContainedInExection < arrTests.count)
        if (yesno("\tSome tests are not in execution. Add them?", true))
            xrayAddTestsToExecution(arrExecutions[0]['issueId'], arrTestIds)
        end
    else
        put_g "Execution: #{arrExecutions.map{|ex| ex['jira']['key']}}"
    end
end

def xrayTestsContainedInExecution?(arrTests)
    arrTests.each { |hTest|
        testKey = hTest['jira']['key']
        testName = hTest['jira']['summary']

        if hTest['testExecutions']['results'].count == 0
            put_r "\tTest #{testKey} #{testName[0..30]}... is not contained in execution"
            exit
        end
    }
end

def xrayTestsRun?(arrTests)
    arrTests.each { |hTest|
        testKey = hTest['jira']['key']
        testName = hTest['jira']['summary']

        if hTest['testRuns']['results'].count > 0
            testRunResult = hTest['testRuns']['results'][0]['status']['name']
            executionKey = hTest['testExecutions']['results'][0]['jira']['key']

            if testRunResult == 'TO DO'
                put_r "        Test #{testKey} #{testName[0..30]}... is not run in test execution: #{executionKey}"
            else
                put_g "        Test #{testKey} #{testName[0..30]}... #{testRunResult} in test execution: #{executionKey}"
            end
        end
    }
end

def xrayTestsContainedInTestPlan?(arrTests)
    arrTests.each { |hTest|
        testKey = hTest['jira']['key']
        testName = hTest['jira']['summary']

        if hTest['testPlans']['results'].count == 0
            put_r "        Test #{testKey} #{testName[0..30]}... is not contained in test plan"
            exit
        end
    }
end

def xrayCreateTestSet(jiraIssueName)
    body = <<EOM
    mutation {
        createTestSet(
            testIssueIds: []
            jira: {
                fields: {
                    summary: "#{jiraIssueName}",
                    project: {key: "SUT"}
                }
            }
        ) {
            testSet {
                issueId
                jira(fields: ["key"])
            }
            warnings
        }
    }
EOM

    response = _xraySendPostRequest(body)

    hResponse=JSON.parse(response.read_body)

    return hResponse['data']['createTestSet']['testSet']['jira']['key']
end

def xrayCreateExecution(executionName)
    body = <<EOM
    mutation {
        createTestExecution(
            jira: {
                fields: {
                    summary: "#{executionName}",
                    project: {key: "SUT"}
                }
            }
        ) {
            testExecution {
                issueId
                jira(fields: ["key"])
            }
            warnings
        }
    }
EOM

    response = _xraySendPostRequest(body)

    hResponse=JSON.parse(response.read_body)

    puts hResponse

    return hResponse['data']['createTestExecution']['testExecution']['issueId']
end

def xrayGetSuiteLabels(suiteId)
    body = <<EOM
    {
        getTestSet(issueId: "#{suiteId}") {
          issueId
          jira(fields: ["key", "labels"])
        }
    }
EOM

    response = _xraySendPostRequest(body)
    hResponse=JSON.parse(response.read_body)

    return hResponse['data']['getTestSet']['jira']['labels']
end

def xrayGetAllTests(projectKey, start, limit)
    body = <<EOM
    {
        getTests(jql: "project = '#{projectKey}'", start: #{start}, limit: #{limit}) {
            total
            start
            limit
            results {
                issueId
                jira(fields: ["key", "summary"])
                folder {name}
                testSets(limit:10) {
                    results{
                        jira(fields: ["key"])
                    }
                }
            }
        }
    }
EOM

    response = _xraySendPostRequest(body)
    hResponse=JSON.parse(response.read_body)

    return hResponse['data']['getTests']
end

def xrayAddTestsToTestSet(testSetId, arrTestIds)
    body = <<EOM
    mutation {
        addTestsToTestSet(
            issueId: "#{testSetId}",
            testIssueIds: #{arrTestIds}
        ) {
            addedTests
            warning
        }
    }
EOM

    response = _xraySendPostRequest(body)
    hResponse=JSON.parse(response.read_body)

    return response.code
end

def xrayAddTestsToExecution(executionId, arrTestIds)
    put_c "execution id: #{executionId}"
    put_c "test ids: #{arrTestIds}"
    body = <<EOM
    mutation {
        addTestsToTestExecution(
            issueId: "#{executionId}",
            testIssueIds: #{arrTestIds}
        ) {
            addedTests
            warning
        }
    }
EOM

    response = _xraySendPostRequest(body)
    hResponse=JSON.parse(response.read_body)

    puts response.code
    puts hResponse
end

def _xraySendPostRequest(body)
    url = URI($config[:xrayGraphqlUrl])

    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Post.new(url)
    request["content-type"] = 'application/json'
    request["authorization"] = "Bearer #{$bearerToken}"

    body = '{"query":"' + body.gsub("\n", ' ').gsub('"', '\\"').squeeze(' ') + '"}'

    request.body = body;

    return http.request(request)
end

def _xraySendGetRequest(body)
    url = URI($config[:xrayGraphqlUrl])

    http = Net::HTTP.new(url.host, url.port)

    request = Net::HTTP::Post.new(url)
    request["content-type"] = 'application/json'
    request["authorization"] = "Bearer #{$bearerToken}"

    body = '{"query":"' + body.gsub("\n", ' ').gsub('"', '\\"').squeeze(' ') + '"}'

    request.body = body;

    return http.request(request)
end