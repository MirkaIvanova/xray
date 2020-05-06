#source: https://gist.github.com/botimer/2891186

# This is a reasonably well-behaved helper for command-line scripts needing to ask a simple yes/no question.
# It optionally accepts a prompt and a default answer that will be returned on enter keypress.
# It keeps asking and echoes the answer on the same line until it gets y/n/Y/N or enter.
# I tried to get Highline to behave like this directly, but even though it's sophisticated, I didn't like the result.
# This isn't especially elegant, but it is straightforward and gets the job done.

require 'highline/import'

def yesno(prompt = 'Continue?', default = true)
  a = ''
  s = default ? '[Y/n]' : '[y/N]'
  d = default ? 'y' : 'n'
  until %w[y n].include? a
    a = ask("#{prompt} #{s} ") { |q| q.limit = 1; q.case = :downcase }
    a = d if a.length == 0
  end
  a == 'y'
end