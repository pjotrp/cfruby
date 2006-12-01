# The Scheduler module defines a generic interface for adding items to a systems cron/scheduler service
#
# Author:: David Powers
# Copyright:: July, 2005
# License:: Ruby License

require 'libcfruby/os'
require 'tempfile'


module Cfruby

	# The Scheduler module defines a generic interface for adding items to a systems cron/scheduler service
	module Scheduler

		# Generic error for scheduler
		class SchedulerError < CfrubyError
		end

		
		# Base class implementation of a Scheduler interface
		class Scheduler
			
			# Schedules +program+ according to +schedule+ (schedule takes standard crontab format).
			# If program is already scheduled according to schedule the call will do nothing silently
			def schedule(program, schedule, user='root')
				Cfruby.controller.attempt("adding \"#{program}\" to crontab", 'reversible', 'destructive') {
					tmp = Tempfile.new('cfruby-cron')
					output = Exec.exec('crontab -u ' + user + ' -l > ' + tmp.path)
					if(output[1].length > 0 && output[1][0] !~ /no crontab for/ )
						raise(SchedulerError, "Unable to get schedule for #{user}")
					end
					added = FileEdit.file_must_contain(tmp.path, "#{schedule} #{program}")
					if(added)
						output = Exec.exec("crontab -u #{user} #{Cfruby::Exec.shellescape(tmp.path)}")
						if(output[1].length > 0)
							raise(SchedulerError, "Unable to schedule \"#{program}\" - #{output[1][1].strip()}")
						end
					else
						Cfruby.controller.attempt_abort("No changes made")
					end
				}
			end

			
			# Removes any scheduled program that matches +regex+ (regex may be given as a String or Regexp, or 
			# an Array of either)
			def unschedule(regex, user='root')
				if(regex.kind_of?(Array))
					regex.each() { |r|
						unschedule(r)
					}
				end
				
				if regex.kind_of?(String)
					regex = Regexp.new(Regexp.escape(String))
				end
				
				Cfruby.controller.attempt("removing \"#{regex.source}\" from crontab", 'nonreversible', 'destructive') {
					if(!regex.kind_of?(Regexp))
						regex = Regexp.new(Regexp.escape(regex.to_s))
					end
					tmp = Tempfile.new('cfruby-cron')
					output = Exec.exec('crontab -u ' + user + ' -l > ' + tmp.path)
					if(output[1].length > 0 && output[1][0] !~ /no crontab for/)
						raise(SchedulerError, "Unable to remove \"#{regex.source()}\" from schedule - #{output[1][1].strip()}")
					end
					added = FileEdit.file_must_not_contain(tmp.path, regex)
					if(added)
						output = Exec.exec("crontab #{Cfruby::Exec.shellescape(tmp.path)}")
						if(output[1].length > 0)
							raise(SchedulerError, "Unable to remove \"#{regex.source()}\" from schedule - #{output[1][1].strip()}")
						end
					else
						Cfruby.controller.attempt_abort("No changes made")
					end
				}
			end
			
		end
		
	end
	
end