require File.expand_path('../../../test_helper', __FILE__)

module Maestrano
  module SSO
    class SessionTest < Test::Unit::TestCase
      setup do
        @mno_session = {
          uid: 'usr-1',
          session: 'g4dfg4fdg8378d6acf45',
          session_recheck: Time.now.utc.iso8601,
          group_uid: 'cld-2'
        }
        @session = {
          maestrano: Base64.encode64(@mno_session.to_json)
        }
      end

      context 'initialization' do
        should "initialize the sso session properly" do
          sso_session = Maestrano::SSO::Session.new(@session)
          assert_equal sso_session.uid, @mno_session[:uid]
          assert_equal sso_session.session_token, @mno_session[:session]
          assert_equal sso_session.recheck, Time.iso8601(@mno_session[:session_recheck])
          assert_equal sso_session.group_uid, @mno_session[:group_uid]
          assert_equal sso_session.preset, 'default'
        end

        context 'with preset on the class' do
          setup do
            @preset = 'my-preset'
            @sso_session = Maestrano::SSO::Session[@preset].new(@session)
          end

          should "capture the preset in session" do
            assert_equal @sso_session.preset, @preset
          end
        end

        context 'with preset in session' do
          setup do
            @preset = 'my-preset'
            @session = {
              maestrano: Base64.encode64(@mno_session.merge(preset: @preset).to_json)
            }
            @sso_session = Maestrano::SSO::Session.new(@session)
          end

          should "capture the preset in session" do
            assert_equal @sso_session.preset, @preset
          end
        end
      end

      context "from_user_auth_hash" do
        setup do
          @auth = {
            extra: {
              session: {
                uid: 'usr-1',
                token: '15fg6d',
                recheck: Time.now,
                group_uid: 'cld-3'
              }
            }
          }
        end

        should "set the session correctly" do
          sso_session = Maestrano::SSO::Session.from_user_auth_hash(@session,@auth)
          assert_equal sso_session.uid, @auth[:extra][:session][:uid]
          assert_equal sso_session.session_token, @auth[:extra][:session][:token]
          assert_equal sso_session.recheck.utc.iso8601, @auth[:extra][:session][:recheck].utc.iso8601
          assert_equal sso_session.group_uid, @auth[:extra][:session][:group_uid]
        end

        context 'with preset' do
          setup do
            @preset = 'my-preset'
            @sso_session = Maestrano::SSO::Session[@preset].from_user_auth_hash(@session,@auth)
          end

          should "capture the preset in session" do
            assert_equal @sso_session.preset, @preset
          end
        end
      end


      context "remote_check_required?" do
        setup do
          @sso_session = Maestrano::SSO::Session.new(@session)
        end

        should "should return true if uid is missing" do
          @sso_session.uid = nil
          assert @sso_session.remote_check_required?
        end

        should "should return true if session_token is missing" do
          @sso_session.session_token = nil
          assert @sso_session.remote_check_required?
        end

        should "should return true if recheck is missing" do
          @sso_session.recheck = nil
          assert @sso_session.remote_check_required?
        end

        should "return true if now is after recheck" do
          Timecop.freeze(@sso_session.recheck + 60) do
            assert @sso_session.remote_check_required?
          end
        end

        should "return false if now is before recheck" do
          Timecop.freeze(@sso_session.recheck - 60) do
            assert !@sso_session.remote_check_required?
          end
        end
      end

      context "perform_remote_check" do
        setup do
          @sso_session = Maestrano::SSO::Session.new(@session)
        end

        should "update the session recheck and return true if valid" do
          recheck = @sso_session.recheck + 600
          RestClient.stubs(:get).returns({'valid' => true, 'recheck' => recheck.utc.iso8601 }.to_json)
          assert @sso_session.perform_remote_check
          assert_equal @sso_session.recheck, recheck
        end

        should "leave the session recheck unchanged and return false if invalid" do
          recheck = @sso_session.recheck
          RestClient.stubs(:get).returns({'valid' => false, 'recheck' => (recheck + 600).utc.iso8601 }.to_json)
          assert !@sso_session.perform_remote_check
          assert_equal @sso_session.recheck, recheck
        end
      end

      context "valid?" do
        setup do
          @sso_session = Maestrano::SSO::Session.new(@session)
          Maestrano.configure { |c| c.sso.slo_enabled = true }
        end

        should "return true if Single Logout is disabled" do
          Maestrano.configure { |c| c.sso.slo_enabled = false }
          @sso_session.stubs(:remote_check_required?).returns(true)
          @sso_session.stubs(:perform_remote_check).returns(false)
          assert @sso_session.valid?
        end

        should "return true if_session is enabled and session is nil" do
          sso_session = Maestrano::SSO::Session.new(nil)
          assert sso_session.valid?(if_session: true)
        end

        should "return true if_session is enabled and session is empty" do
          sso_session = Maestrano::SSO::Session.new({})
          assert sso_session.valid?(if_session: true)
        end

        should "return true if no remote_check_required?" do
          @sso_session.stubs(:remote_check_required?).returns(false)
          assert @sso_session.valid?
          assert @sso_session.valid?(if_session: true)
        end

        should "return true if remote_check_required? and valid" do
          @sso_session.stubs(:remote_check_required?).returns(true)
          @sso_session.stubs(:perform_remote_check).returns(true)
          assert @sso_session.valid?
          assert @sso_session.valid?(if_session: true)
        end

        should "update maestrano session with recheck timestamp if remote_check_required? and valid" do
          recheck = (@sso_session.recheck + 600)
          @sso_session.recheck = recheck
          @sso_session.stubs(:remote_check_required?).returns(true)
          @sso_session.stubs(:perform_remote_check).returns(true)
          @sso_session.valid?
          assert_equal JSON.parse(Base64.decode64(@session[:maestrano]))['session_recheck'], recheck.utc.iso8601
        end

        should "return false if remote_check_required? and invalid" do
          @sso_session.stubs(:remote_check_required?).returns(true)
          @sso_session.stubs(:perform_remote_check).returns(false)
          assert_false @sso_session.valid?
          assert_false @sso_session.valid?(if_session: true)
        end

        should "return false if internal session is nil" do
          sso_session = Maestrano::SSO::Session.new(nil)
          assert_false @sso_session.valid?
        end
      end

      context 'with preset' do
        context "valid?" do
          setup do
            @preset = 'my-preset'
            @sso_session = Maestrano::SSO::Session[@preset].new(@session)
            Maestrano[@preset].configure { |c| c.sso.slo_enabled = true }
          end

          should "return true if Single Logout is disabled" do
            Maestrano[@preset].configure { |c| c.sso.slo_enabled = false }
            @sso_session.stubs(:remote_check_required?).returns(true)
            @sso_session.stubs(:perform_remote_check).returns(false)
            assert @sso_session.valid?
          end

          should "return true if_session is enabled and session is nil" do
            sso_session = Maestrano::SSO::Session[@preset].new(nil)
            assert sso_session.valid?(if_session: true)
          end

          should "return true if_session is enabled and session is empty" do
            sso_session = Maestrano::SSO::Session[@preset].new({})
            assert sso_session.valid?(if_session: true)
          end

          should "return true if no remote_check_required?" do
            @sso_session.stubs(:remote_check_required?).returns(false)
            assert @sso_session.valid?
            assert @sso_session.valid?(if_session: true)
          end

          should "return true if remote_check_required? and valid" do
            @sso_session.stubs(:remote_check_required?).returns(true)
            @sso_session.stubs(:perform_remote_check).returns(true)
            assert @sso_session.valid?
            assert @sso_session.valid?(if_session: true)
          end

          should "update maestrano session with recheck timestamp if remote_check_required? and valid" do
            recheck = (@sso_session.recheck + 600)
            @sso_session.recheck = recheck
            @sso_session.stubs(:remote_check_required?).returns(true)
            @sso_session.stubs(:perform_remote_check).returns(true)
            @sso_session.valid?
            assert_equal JSON.parse(Base64.decode64(@session[:maestrano]))['session_recheck'], recheck.utc.iso8601
          end

          should "return false if remote_check_required? and invalid" do
            @sso_session.stubs(:remote_check_required?).returns(true)
            @sso_session.stubs(:perform_remote_check).returns(false)
            assert_false @sso_session.valid?
            assert_false @sso_session.valid?(if_session: true)
          end

          should "return false if internal session is nil" do
            sso_session = Maestrano::SSO::Session[@preset].new(nil)
            assert_false @sso_session.valid?
          end
        end
      end

    end
  end
end
