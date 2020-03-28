require 'uri'
require 'net/http'
require 'openssl'
require 'json'
require 'pp'
require './config'

def jiraGetLinkedTestSets(key)
    url = URI($config[:jiraUrl] + "issue/" + key)

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(url)
    request["authorization"] = $config[:jiraAuth]

    response = http.request(request)
    hResponse=JSON.parse(response.read_body)

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

def jiraIssueIsTestedByTestSet(jiraIssueKey)
    arrTestSets=jiraGetLinkedTestSets (jiraIssueKey)

    if arrTestSets.count == 0
        put_r "Issue #{jiraIssueKey} has no linked test set with relation \"is tested by\""
        exit
    end

    put_g "Issue #{jiraIssueKey} has linked test set"

    return arrTestSets
end