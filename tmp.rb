#!/usr/bin/ruby

#sudo gem install highline
#sudo gem install colorize

require 'colorize'
require './colors'
require './jira'
require './xray'
require './yesno'

xrayGetBearerToken()

start=0
limit = 100

readTests=0
testsWithoutSuite = []

loop do
    res=xrayGetAllTests("STCN", start, limit)

    thisIterationTests=res['results']
    totalTests=res['total']
    start=start+thisIterationTests.count
    limit=res['limit']

    readTests=readTests + thisIterationTests.count

    testsWithoutSuite += thisIterationTests.select {|resTest| resTest['testSets']['results'].count==0 }

    break if readTests == totalTests
end

testsWithoutSuite.each {|test|
    summary="%-61s" % test['jira']['summary'][0..60]
    puts "#{test['jira']['key']} #{summary}... #{test['folder']['name']}"
}