require_relative '../test_helper'
require_relative '../../lib/params_ready'
require_relative '../../lib/params_ready/value/custom'

module ParamsReady
  module Examples
    class Rails
      def self.logger
        @logger ||= Logger.new
      end

      class Logger
        def initialize
          @messages = {}
        end

        def info(msg)
          message(:info, msg)
        end

        def message(level, msg)
          @messages[level] ||= []
          @messages[level] << msg
        end
      end
    end
    class ApplicationController
      include ParamsReady::ParameterUser
      include ParamsReady::ParameterDefiner

      attr_reader :action_name, :params, :current_user

      class AuthenticationError < StandardError; end
      class AuthorizationError < StandardError; end
      class NotFoundError < StandardError; end
      class ServerError < StandardError; end
      class SessionExpired < StandardError; end

      def initialize(action_name, params, current_user)
        @action_name = action_name
        @params = params
        @current_user = current_user
      end

      def authority
        { index: [:admin] }
      end

      def self.before_action(method_name)
        @before_action ||= []
        @before_action << method_name
      end

      def self.before_action_callbacks
        cb = @before_action || []
        return cb unless superclass.respond_to? :before_action_callbacks

        superclass.before_action_callbacks + cb
      end

      before_action :populate_params

      def process
        self.class.before_action_callbacks.each do |method_name|
          send method_name
        end

        send @action_name
      end

      attr_reader :prms

      def populate_params
        # Provide formatting information
        format = ParamsReady::Format.instance(:frontend)
        # If initialization of some parameters requires additional
        # data, pass them in within the context object
        data = { current_user: current_user, authority: authority }
        context = ParamsReady::InputContext.new(format, data)

        result, @prms = populate_state_for(action_name.to_sym, params, context)
        if result.ok?
          # At this point, parameters are guaranteed to be correctly initialized
          Rails.logger.info("Action #{action_name}, parameters: #{@prms.unwrap}")
          # It's recommended to freeze parameters after initialization
          @prms.freeze
        else
          params_ready_errors = result.errors
          # Error handling goes here ...
        end
      rescue AuthenticationError, AuthorizationError, NotFoundError, ServerError, SessionExpired => e
        # Error handling for specific errors ...
      rescue StandardError => e
        # Error handling for generic errors ...
      end

      def assigns
        instance_variables.map do |name|
          plain_name = name.to_s.delete('@').to_sym
          value = instance_variable_get name
          [plain_name, value]
        end.to_h
      end
    end

    class UsersParameters
      include ParamsReady::ParameterDefiner
      define_relation :users do
        operator { local :and }
        model User
        fixed_operator_predicate :name_match, attr: :name do
          type :value, :non_empty_string
          operator :like
          optional
        end

        fixed_operator_predicate :email_match, attr: :email do
          type :value, :non_empty_string
          operator :like
          optional
        end

        paginate 10, 100
        order do
          column :email, :asc
          column :name, :asc, nulls: :last
          column :role, :asc
          default [:email, :asc], [:role, :asc]
        end
        default :inferred
        memoize
      end
    end

    class PostsController < ApplicationController
      include_relations UsersParameters
      use_relation :users, only: [:index, :show]

      define_relation :posts do
        operator { local :and }

        fixed_operator_predicate :user_id_eq, attr: :user_id do
          type :value, :integer
          operator :equal
          optional
        end

        join_table User.arel_table, :inner do
          on(:user_id).eq(:id)
        end
        fixed_operator_predicate :subject_match, attr: :subject do
          type :value, :non_empty_string
          operator :like
          optional
        end
        paginate 10, 100
        order do
          column :email, :asc, arel_table: User.arel_table
          column :subject, :asc
          default [:email, :asc], [:subject, :asc]
        end
        default :inferred
        memoize
      end
      use_relation :posts, only: [:index, :show]

      define_parameter :integer, :id
      use_parameter :id, only: [:show]

      def index
        @posts = prms.relation(:posts).build_relation(include: [:user], scope: Post.all)
        @count = prms.relation(:posts).perform_count(scope: Post.all)
      end

      def show
        @post = Post.find_by id: @prms[:id].unwrap
      end
    end

    class IntegrationExamples < Minitest::Test
      def test_helper_functions_on_state_work
        hash = {
          users: { name_match: 'John', pgn: '2-10', ord: 'email-desc' },
          posts: { user_id_eq: '1', subject_match: 'Question', pgn: '5-10', ord: 'subject-asc|email-desc' }
        }
        params = ActionCtrl::Parameters.new(hash)
        ctrl = PostsController.new(:index, params, User.new(id: 1, email: 'user@example.com', role: 'admin'))
        ctrl.process

        assert_equal hash, ctrl.prms.current
        assert_equal({ users: { name_match: 'John', pgn: '2-10', ord: 'email-desc' }}, ctrl.prms.for_frontend(restriction: Restriction.permit(:users)))

        reset = ParamsReady::Restriction.permit(:users, posts: [:user_id_eq])
        reset_page = {
          users: { name_match: 'John', pgn: '2-10', ord: 'email-desc' },
          posts: { user_id_eq: '1' }
        }
        assert_equal reset_page, ctrl.prms.for_frontend(restriction: reset)

        out = OutputParameters.decorate(ctrl.prms.freeze)
        assert_equal 'posts[subject_match]', out[:posts][:subject_match].scoped_name
        assert_equal 'Question', out[:posts][:subject_match].format
        flat_pairs = [
          ['users[name_match]', 'John'],
          ['users[pgn]', '2-10'],
          ['users[ord]', 'email-desc'],
          ['posts[user_id_eq]', '1']
        ]
        assert_equal flat_pairs, out.flat_pairs(restriction: reset)

        toggled = {
          users: { name_match: 'John', pgn: '2-10', ord: 'email-desc' },
          posts: { user_id_eq: '1', subject_match: 'Question', ord: 'subject-desc|email-desc' }
        }
        assert_equal toggled, ctrl.prms.toggle(:posts, :subject)
        assert_equal 2, ctrl.prms.page_no(:posts)
        assert_equal 10, ctrl.prms.num_pages(:posts, count: 100)
        assert ctrl.prms.has_previous?(:posts, 1)
        refute ctrl.prms.has_previous?(:posts, 2)
        assert ctrl.prms.has_next?(:posts, 1, count: 100)
        refute ctrl.prms.has_next?(:posts, 11, count: 100)
        previous_page = {
          users: { name_match: 'John', pgn: '2-10', ord: 'email-desc' },
          posts: { user_id_eq: '1', subject_match: 'Question', ord: 'subject-asc|email-desc' }
        }
        assert_equal previous_page, ctrl.prms.previous(:posts, 1)
        next_page = {
          users: { name_match: 'John', pgn: '2-10', ord: 'email-desc' },
          posts: { user_id_eq: '1', subject_match: 'Question', pgn: '15-10', ord: 'subject-asc|email-desc' }
        }
        assert_equal next_page, ctrl.prms.next(:posts, 1)
        first_page = {
          users: { name_match: 'John', pgn: '2-10', ord: 'email-desc' },
          posts: { user_id_eq: '1', subject_match: 'Question', ord: 'subject-asc|email-desc' }
        }
        assert_equal first_page, ctrl.prms.first(:posts)
      end
    end
  end
end