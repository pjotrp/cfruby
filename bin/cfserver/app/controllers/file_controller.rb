require 'rcs.rb'
require 'tempfile'
require 'yaml'

class FileController < ApplicationController
		
	def upload()
	end
	
	
	def save()
		# get an RCS instance
		rcs = get_rcs()
		
		# new file parameters
		name = params[:file][:file_upload].original_filename
		
		# build a location from the params
		location = get_location_class.new(params[:location])
		
		# save the file to a temp location
		upload = Tempfile.new('rcs')
		data = params[:file][:file_upload].read(2048)
		while(data != nil)
			upload.write(data)
			data = params[:file][:file_upload].read(2048)
		end
		upload.close()
		
		rcs.add(upload.path, location, params[:file][:changelog])
	end
	
	private
	
	def get_rcs()
		rcsconfig = YAML.load_file(File.dirname(__FILE__) + "/../../config/rcs.yml")

		begin
			rcsclass = RCS.const_get(rcsconfig['rcstype'])
		rescue NameError
			raise(StandardError, "Unsupported RCS type")
		end
		if(!rcsclass.ancestors.include?(RCS::RCSBase))
			raise(StandardError, "Unsupported RCS type")
		end
		
		return(rcsclass.new(:location => File.dirname(__FILE__) + "/../../" + rcsconfig['rcspath']))
	end
	
	
	def get_location_class
		rcsconfig = YAML.load_file(File.dirname(__FILE__) + "/../../config/rcs.yml")

		begin
			locationclass = RCS.const_get(rcsconfig['locationtype'])
		rescue NameError
			raise(StandardError, "Unsupported RCS Location type")
		end
		if(!locationclass.ancestors.include?(RCS::Location))
			raise(StandardError, "Unsupported RCS Location type")
		end
		
		return(locationclass)
	end
end
