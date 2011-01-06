# This class differs from the standard cfrubylib edition - as it is aimed
# at checking the checksum of a buffer/array - and allows for skipping
# certain comments which get inserted by Cfruby itself(!)
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

require 'md5' if RUBY_VERSION =~ /^1\.8/

module Cfp_Cksum

	# The cksum method calculates a checksum - skipping lines that look like
	# 'skip'

	def cksum object, skip = nil
		if object.class.to_s == 'Array'
			return cksum_a(object,skip)
		end
		if object.class.to_s == 'File'
			lines = Array.new
			object.each_line do | ln |
				lines.push ln
			end
			return cksum_a(lines,skip)
		end
		raise "Unrecognized object #{object.class}"
	end

private 

	def cksum_a lines, skip
		# ---- We have to skip date stamps
		a = Array.new
		lines.each do | ln |
			skip = '# WARNING: DO NOT CHANGE THIS FILE' if skip == nil
			# a.push ln.chomp if ln !~ /\# WARNING: DO NOT CHANGE THIS FILE - it is maintained by/
			a.push ln.chomp if ln !~ /#{skip}/
		end
		# p a
		MD5.hexdigest(a.join("\n").chomp)
	end


end
