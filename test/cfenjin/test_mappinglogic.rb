# Test the mapping of Cfenjin style parameters to libcfruby options

require 'test/unit'
require 'libcfenjin/cfp_mapoptions'

class TC_CfrubyMappingLogic < Test::Unit::TestCase

		include Cfruby::Cfp_MapOptions
		
	def test_recursive
		assert_equal({:filesonly=>true,:recursive=>true,:followsymlinks=>false},map('tidy',{'recurse'=>'inf'}))
		assert_equal({:filesonly=>true,:depth=>2,:followsymlinks=>false},map('tidy',{'recurse'=>'2'}))
		assert_raises(UnknownParameterError) {
			map('tidy',{'recurse'=>'xx'}) 
		}
	end

	def test_rmdirs
		assert_equal({:force=>true,:followsymlinks=>false},map('tidy',{'rmdirs'=>'TRUE'}))
		assert_equal({:filesonly=>true,:followsymlinks=>false},map('tidy',{'rmdirs'=>'false'}))
		assert_equal({:filesonly=>true,:followsymlinks=>false},map('tidy',{}))
	end

	def test_files
		assert_equal({:glob=>'1*'},map('files',{'pattern'=>'1*'}))

		# ---- Old style:
		parser = Cfruby::Parser.new
		# test simple
		attrib = { 'o' => 'user', 'g' => 'users', 'm' => 0744 }
		options = parser.map('files',attrib)
		assert_equal({:group=>"users", :mode=>484, :user=>"user"},options)
		# test mismatch
		attrib = { 'o' => 'user', 'g' => 'users', 'm' => 0744, 'parameter' => 'unknown' }
		assert_raise(Cfruby::Cfp_MapOptions::UnknownParameterError) { parser.map('files',attrib) }
		# test pop options
		(user,group,mode) = parser.pop_options(options,:user,:group,:mode)
		assert_equal(["user", "users", 484, {}],[user,group,mode,options])

		# Test with recursing and fixplain
		attrib = { 'o' => 'user', 'g' => 'users', 'm' => 0744, 'rec'=>'inf', 'act'=>'fixplain' }
		options = parser.map('files',attrib)
		assert_equal({:group=>"users", :mode=>484, :recursive=>true, :user=>"user", :filesonly=>true},options)
		# Test with recursing and fixdirs
		attrib = { 'o' => 'user', 'g' => 'users', 'm' => 0744, 'rec'=>'inf', 'act'=>'fixdirs' }
		options = parser.map('files',attrib)
		assert_equal({:group=>"users", :mode=>484, :recursive=>true, :user=>"user", :directoriesonly=>true},options)
	end

	def test_complex
	end



end

