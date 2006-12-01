# Map Cfruby style options to cfrubylib. Cfruby uses Cfengine style attributes
# for files, directories, copy etc. These do not map one-to-one with cfrubylib.
# 
# The mapping is based on a synonym list and a mapping table (implemented as
# a hash). Straightforward mapping and default values are read straight from
# the table. If it gets more complicated (for example because cfrubylib 
# requires multiple options to be passed) an inplace Proc is called that 
# does the mapping (part of +Args+ module).
#
# To see some mappings at work visit ./test/test_parserlogic.rb

module Cfruby

	module Cfp_MapOptions

		class UnknownParameterError < Cfruby::CfrubyError
		end

		module Args

      def Args.test(value,tests)
        return false if value == nil
        tests.each do | t |
          value = value.downcase if value.kind_of? String
          return true if (t == value)
        end
        false
      end

			def Args.recurse name,value 
        if test(value,['infinite','true'])
					return { :recursive => true }
				elsif value.to_s =~ /\d+/
          # don't set :recursive in this case
					return { :depth => value.to_i }
				end
        return {} if value == nil or value.downcase == 'false'
        raise UnknownParameterError,"Unknown value '#{value}' for '#{name}'"
			end

			def Args.action name,value
				if test(value,'fixplain')
					return { :filesonly => true }
				elsif value == 'fixdirs'
					return { :directoriesonly => true }
				end
        return {} if value == nil or value == 'fixall'
				raise UnknownParameterError,"Unknown value '#{value}' for '#{name}'"
			end

      def Args.rmdirs name,value
        if value!=nil and value.downcase =~ /^t/
          return { :force => true }
        else
          return { :filesonly => true }
        end
			end

      def Args.age name,value
        if value != nil
          days = value.to_i 
          raise UnknownParameterError,"Unknown value '#{value}' for '#{name}'" if days<1
          return { :olderthan => Time.now - days*24*3600 }
        end
        return {} if value == nil
				raise UnknownParameterError,"Unknown value '#{value}' for '#{name}'"
			end


		end


		# Synonym list - may be read from file later
		SYNONYM = {
			'a' => 'action', 'act'=>'action',
			'b' => 'backup',
			'm' => 'mode',
			'd' => 'dest',
			'o' => 'owner',
			'g' => 'group',
			'r' => 'recurse', 'rec'=>'recurse',
      'p' => 'pattern',
			'inf' => 'infinite'
		}

		EMPTY_OPT  = {}
		# Shared file options
		FILE_OPT   = { 
			'mode' => [ :mode ], 'owner' => [ :owner ], 'group' => [ :group ]
		}
    RECURSE_OPT = { 
      'recurse'	=> [ :void, Proc.new { |n,v| Args.recurse(n,v) } ] 
    }
    AGE_OPT = { 
      'age'	=> [ :void, Proc.new { |n,v| Args.age(n,v) } ] 
    }
    PATTERN_OPT    = {
      'pattern' => [ :glob ]
    }
    REMOVE_OPT = {
      'rmdirs'	=> [ :void, Proc.new { |n,v| Args.rmdirs(n,v) } ] 
    }
    # ==== Main action arrays
		# directories: 
		#   dirname m=766 o=myname ...
		DIR    = [ { 'mode' => [ :mode, 0775 ], 
        'makeparent' => [ :makeparent, true] }, FILE_OPT 
    ]
		# files:
		#   filename o=user g=user m=444 rec=inf ...
		FILES  = [ RECURSE_OPT, FILE_OPT, PATTERN_OPT,
      { 'action' 	=> [ :void, Proc.new { |n,v| Args.action(n,v) } ] }
    ]
		# FILES_OPT  = [ { 'recurse' => [ :recursive, false ], 'action' => [:filesonly, false] }, FILE_OPT ]
		# copy:
		#   filename dest=destname o=user ...
		COPY   = [ { 'mode' => [ :mode, 0400 ], 'backup' => [ :backup, true ] ,
			'onlyonchange' => [ :onlyonchange , true ], 'force' => [ :force, true ] }, 
			FILE_OPT ]
    TIDY   = [ RECURSE_OPT, REMOVE_OPT, PATTERN_OPT, AGE_OPT, 
			{ 'links' => [ :followsymlinks, false ] }
    ]
		# map a Cfruby method with its options
		MAP        = { 
			'directories' => DIR,
			'files'       => FILES,
			'copy'        => COPY,
			'tidy'        => TIDY
		}

		# Attributes are mapped including default values. The first options
		# found in the map is returned. If an option is not on the MAP an
		# exception is raised. Mind: options handled by the Cfruby parser
		# itself are deleted beforehand (see cfrubyruntime.rb) by a call to
		# pop_options.
		#
		# Each option that is legal should be in the list. The translated
		# value is pointed to. The second parameter is the default value -
		# which can be a method that is called instead to figure out the
		# right value. Examples:
		#
		# Just translate the value of mode m=444
		# 	'mode' => [ :mode ]
		# Pass the default value of mode if not given
		# 	'mode' => [ :mode, 0644 ]
		# Call the translator method on m=444, passing the value as a parameter
		# 	'mode' => [ :mode, translate_mode ]

		def map action,attribs
			ret_options = {}
			argslist = expand_synonyms(attribs) # keeps track of found items
			# argslist contains Cfruby style options list, e.g. 
			#   {"mode"=>0644, "owner"=>"user", "group"=>"users"}
			#
			# with this list walk the whole map
			MAP[action].each do | maps |
				maps.each do | option, a |
					name = synonym(option)
					value = synonym(argslist[name])
					parname = a[0]
					default = a[1]
					# p [name,value,default,a]
					isproc = (default and default.kind_of? Proc)
          if isproc
						# it is an in place method, so let it handle the request
						ret_options.merge! default.call(name,value)
						argslist.delete(name)
          else  
            if value != nil
              # ---- a value was passed (e.g. mode=0644)
							# Use the actual value
							ret_options[parname] = value
              argslist.delete(name)
					  elsif default != nil
              # ---- no value passed, but a default value is available
              ret_options[parname] = default
              argslist.delete(name)
            else
              # ---- No value and no default! Just means this is a legal and
              # unused parameter
              next
            end
          end
				end
			end
			if argslist.size > 0
				raise UnknownParameterError,"Unresolved options for action '#{action}': <#{argslist.keys.join(',')}>"
			end
			# p [ret_options]
			ret_options
		end

    # If a pattern parameter is supported make sure recurse is set
    # to 1 if the filename points to a directory.
    def check_pattern attrib,filename
      return attrib if attrib['recurse']!=nil
      attrib['recurse']='1' if attrib['pattern'] and File.directory?(filename)
      attrib
    end

		# Remove options from a list and return them
		def pop_options opts,*named
			ret = []
			named.each do | n |
				ret.push opts[n]
				opts.delete(n)
			end
			ret
		end

		def synonym name
			if name!= nil and name.kind_of?(String) and SYNONYM[name.downcase]
				return SYNONYM[name]
			end
			name
		end
		
		# Clone a list with expanded keywords
		def expand_synonyms list
			explist = {}
			list.each do | key, value |
				explist[synonym(key)] = value
			end
			explist
		end

	end

end
