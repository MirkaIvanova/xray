require 'uri'
require 'net/http'
require 'openssl'
require 'json'
require 'pp'
require './config'

def jiraGetLinkedTestSets(key)
    url = URI($config[:jiraUrl] + "issue/" + key)

    response=_jiraSendGetRequest(url)
    hResponse=JSON.parse(response.read_body)

    return [] if (response.code != "200")

    testSets = []
    hResponse['fields']['issuelinks'].each { |link|
        next if !link.key?('inwardIssue')

        linkInwardId=link['inwardIssue']['id']
        linkIssueType=link['inwardIssue']['fields']['issuetype']['name']
        linkInwardType=link['type']['inward']

        if linkInwardType == 'is tested by' && linkIssueType == 'Test Set'
            testSets << linkInwardId
        end
    }

    return testSets
end

def jiraGetIssueSummary(key)
    url = URI($config[:jiraUrl] + "issue/" + key)

    response=_jiraSendGetRequest(url)

    return nil if (response.code != "200")

    hResponse=JSON.parse(response.read_body)

    return hResponse['fields']['summary']
end

def _jiraSendGetRequest(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(url)
    request["authorization"] = $config[:jiraAuth]

    return http.request(request)
end

def jiraCreateIssueLinks(outwardIssue, inwardIssue, linkType)
    url = URI($config[:jiraUrl] + "issueLink")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request["authorization"] = $config[:jiraAuth]
    request["content-type"] = 'application/json'

    body = <<EOM
    {
        "outwardIssue": {
          "key": "#{outwardIssue}"
        },
        "inwardIssue": {
          "key": "#{inwardIssue}"
        },
        "type": {
          "name": "#{linkType}"
        }
    }
EOM

    body = body.gsub("\n", ' ').gsub('"', '"').squeeze(' ')

    request.body = body;

    response = http.request(request)

    return response.code
end

def jiraGetTestsWithLabel(label)
    url = URI($config[:jiraUrl] + "search")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request["authorization"] = $config[:jiraAuth]
    request["content-type"] = 'application/json'

    # TODO: Handle if more than 100 tests returned
    body = <<EOM
    {
        "jql": "labels = #{label} and issuetype=Test",
        "maxResults": 100,
        "fieldsByKeys": false,
        "fields": [
          "summary"
        ],
        "startAt": 0
      }
EOM

    body = body.gsub("\n", ' ').squeeze(' ')

    request.body = body;

    response = http.request(request)
    hResponse=JSON.parse(response.read_body)

    return hResponse['issues'].map {|i| i['id']}
end

def jiraAddLabels(issueId, arrLabels)

    url = URI($config[:jiraUrl] + "issue/#{issueId}")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Put.new(url)
    request["authorization"] = $config[:jiraAuth]
    request["content-type"] = 'application/json'

    puts "{\"update\": { \"labels\": [ {\"add\": \"Map\" }, {\"add\": \"Material\"},{\"add\": \"SUP-1199\" }] } }"

    body = '{"update": { "labels": [ '
    arrLabels.each {|label|
        body += "{\"add\": \"#{label}\" },"
    }

    body = body.chomp(',') + "] } }"

    puts body

    request.body = body;
    response = http.request(request)
    puts response.code
end