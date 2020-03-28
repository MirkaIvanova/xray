
require 'uri'
require 'net/http'
require './config'

$bearerToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0ZW5hbnQiOiJkNjdmOGZhNS01MTNmLTNmOTgtYTEzZC01NDdiOTgzYTU1ZmIiLCJhY2NvdW50SWQiOiI1ZDM4MzNmNDZlNTUzNzBiYzMwOGU3YTkiLCJpYXQiOjE1ODUzNDAyODcsImV4cCI6MTU4NTQyNjY4NywiYXVkIjoiMTk0NTZENzhFQ0Q3NDI0M0EyQjc5RjNFNUE5MEQwRTEiLCJpc3MiOiJjb20ueHBhbmRpdC5wbHVnaW5zLnhyYXkiLCJzdWIiOiIxOTQ1NkQ3OEVDRDc0MjQzQTJCNzlGM0U1QTkwRDBFMSJ9.KdmQrq7qz_chNtHZQwQCrWO1IhGv2zOI_3zXBu2c7yc';

def xrayTestSetContainsTests?(testSet)
    testCount = testSet['tests'].count

    if testCount == 0
        put_r "    TestSet #{testSet['key']} contains no tests!"
        exit
    else
        put_g "    TestSet #{testSet['key']} contains #{testCount} tests"
    end
end

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

def xrayGetTestSetTests(testSetId)
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
                jira (fields: ["key"])
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
        'tests' => hResponse['data']['getTestSet']['tests']['results']
    }
end

def xrayTestsContainLabel?(arrTests, jiraIssueKey)
    arrTests.each { |hTest|
        labels = hTest['jira']['labels']
        testKey = hTest['jira']['key']

        if !labels.include? jiraIssueKey
            put_r "        Test #{testKey} has no label '#{label}'"
            exit
        end
    }
end

def xrayTestsContainedInExecution?(arrTests)
    arrTests.each { |hTest|
        testKey = hTest['jira']['key']
        testName = hTest['jira']['summary']

        if hTest['testExecutions']['results'].count == 0
            put_r "        Test #{testKey} #{testName[0..30]}... is not contained in execution"
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