require File.dirname(__FILE__) + '/../test_helper'
require 'file_controller'

# Re-raise errors caught by the controller.
class FileController; def rescue_action(e) raise e end; end

class FileControllerTest < Test::Unit::TestCase
  def setup
    @controller = FileController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
