#!/usr/bin/ruby

#sudo gem install highline
#sudo gem install colorize

require 'colorize'
require './colors'
require './jira'
require './xray'
require './yesno'

jiraIssueKey = ARGV[0]

if jiraIssueKey.nil?
    jiraIssueKey='SUP-1199'
end

put_c "Issue \"#{jiraIssueKey}\""

xrayGetBearerToken()

jiraIssueName = jiraGetIssueSummary(jiraIssueKey)

if (!jiraIssueName)
    put_r "Jira issue \"#{jiraIssueKey}\" not found!"
    exit
end

arrTestSets = jiraGetLinkedTestSets(jiraIssueKey)

if arrTestSets.count == 0
    put_r "No linked suite."

    if (yesno("Create it now?", true))
        testSetName = "[#{jiraIssueKey}] #{jiraIssueName}"

        testSetKey = xrayCreateTestSet(testSetName)
        res = jiraCreateIssueLinks(jiraIssueKey, testSetKey, "Test")

        if (res != "201")
            put_r "Cannot create test set"
            exit
        end

        arrTestSets = jiraGetLinkedTestSets(jiraIssueKey)
    else
        exit
    end
end

arrTestSets.each {|suiteId|
    testSet = xrayGetSuite (suiteId)
    arrTests = testSet['tests']

    put_g "Suite: #{testSet['key']}"

    if (xrayTestSetContainsTests?(testSet) == 0)
        put_r "\tSuite #{testSet['key']} contains no tests!"
        arrExistingTests = jiraGetTestsWithLabel(jiraIssueKey)
        if ( arrExistingTests.count > 0)
            if (yesno("\tThere are #{arrExistingTests.count} tests with label #{jiraIssueKey}. Add them to test set #{testSet['key']}?", true))
                xrayAddTestsToTestSet(suiteId, arrExistingTests)
            end
        else
            put_r "\tNo tests found with label \"#{jiraIssueKey}\""
            exit
        end
    end

    allTestsLabels = xrayTestsContainLabel?(arrTests, jiraIssueKey)

    suiteLabels = xrayGetSuiteLabels(suiteId)

    if (suiteLabels.count < allTestsLabels.count)
        if (yesno("\tAdd labels to suite? #{allTestsLabels}", true))
            jiraAddLabels(suiteId, allTestsLabels)
        end
    end

    xrayCreateExecutionAndAddTests(testSet['summary'], arrTests)
    arrTests = (xrayGetSuite (suiteId))['tests']

    xrayTestsContainedInTestPlan?(arrTests)
    xrayTestsContainedInExecution?(arrTests)
    xrayTestsRun?(arrTests)

}




