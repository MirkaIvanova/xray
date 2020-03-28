#!/usr/bin/ruby

require 'colorize'
require './colors'
require './jira'
require './xray'

jiraIssueKey = ARGV[0]

if jiraIssueKey.nil?
    jiraIssueKey='SUP-575'
end

put_c "Checking whether issue #{jiraIssueKey} contains tests:\n"

xrayGetBearerToken()

arrTestSets = jiraIssueIsTestedByTestSet(jiraIssueKey)

arrTestSets.each {|testSetId|
    testSet = xrayGetTestSetTests (testSetId)
    arrTests = testSet['tests']

    xrayTestSetContainsTests?(testSet)
    xrayTestsContainLabel?(arrTests, jiraIssueKey)
    xrayTestsContainedInExecution?(arrTests)
    xrayTestsRun?(arrTests)
    xrayTestsContainedInTestPlan?(arrTests)
}




