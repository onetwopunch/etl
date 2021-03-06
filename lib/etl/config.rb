require 'etl/util/hash_util'
require 'psych'
require 'singleton'

module ETL

  # Configuration class
  class Config
    attr_accessor :config_dir, :db

    include Singleton

    def initialize
      @config_dir = ENV['ETL_CONFIG_DIR'] || File.expand_path('../../../etc', __FILE__)
    end

    def db_file
      @config_dir + "/database.yml"
    end

    def db(&b)
      get_envvars = is_true_value(ENV.fetch('ETL_DATABASE_ENVVARS', false))
      @db ||= if get_envvars
                value = database_env_vars
                { etl: value, test: value}
              else
                self.class.load_file(db_file)
              end
      yield @db if block_given?
      @db
    end

    def database_env_vars(prefix="ETL_DATABASE")
      conn_params = {}
      conn_params[:dbname] = ENV.fetch("#{prefix}_DB_NAME", 'postgres')
      conn_params[:user] = ENV.fetch("#{prefix}_USER", 'root')
      conn_params[:password] = ENV.fetch("#{prefix}_PASSWORD")
      conn_params[:host] = ENV.fetch("#{prefix}_HOST", 'localhost')
      conn_params[:port] = ENV.fetch("#{prefix}_PORT", 5432)
      conn_params[:adapter] = ENV.fetch("#{prefix}_ADAPTER", 'postgres')
      conn_params
    end

    def aws_file
      @config_dir + "/aws.yml"
    end

    def aws(&b)
      get_envvars = ENV.fetch('ETL_AWS_ENVVARS', false)
      @aws ||= if is_true_value(get_envvars)
                aws_hash = {}
                aws_hash[:region] = ENV.fetch('ETL_AWS_REGION', 'us-west-2')
                aws_hash[:s3_bucket] = ENV.fetch('ETL_AWS_S3_BUCKET')
                aws_hash[:role_arn] = ENV.fetch('ETL_AWS_ROLE_ARN')
                aws_hash
                { test: aws_hash, etl: aws_hash }
              else
                self.class.load_file(aws_file)
              end
      yield @aws if block_given?
      @aws
    end

    def redshift_env_vars(prefix: "ETL_REDSHIFT")
      redshift_hash = {}
      redshift_hash[:user] = ENV.fetch("#{prefix}_USER", 'masteruser')
      redshift_hash[:password] = ENV.fetch("#{prefix}_PASSWORD")
      redshift_hash[:driver] = ENV.fetch("#{prefix}_DRIVER", 'Amazon Redshift (x64)')
      redshift_hash[:server] = ENV.fetch("#{prefix}_HOST")
      redshift_hash[:tmp_dir] = ENV.fetch("#{prefix}_TMP_DIR", '/tmp')
      redshift_hash
    end

    def redshift_file
      @config_dir + "/redshift.yml"
    end

    def redshift(&b)
      get_envvars = is_true_value(ENV.fetch('ETL_REDSHIFT_ENVVARS', false))
      @redshift ||= if get_envvars
                      value = redshift_env_vars
                      { etl: value, test: value}
                    else
                      self.class.load_file(redshift_file)
                    end
      yield @redshift if block_given?
      @redshift
    end

    def influx_file
      @config_dir + "/influx.yml"
    end

    def influx(&b)
      get_envvars = is_true_value(ENV.fetch('ETL_INFLUX_ENVVARS', false))
      @influx ||= if get_envvars
                    influx_hash = {}
                    influx_hash[:password] = ENV.fetch('ETL_INFLUXDB_PASSWORD')
                    influx_hash[:port] = ENV.fetch('ETL_INFLUXDB_PORT', 8086)
                    influx_hash[:host] = ENV.fetch('ETL_INFLUXDB_HOST', 'influxdb.service.consul')
                    influx_hash[:database] = ENV.fetch('ETL_INFLUXDB_DB', 'metrics')
                    influx_hash
                  else
                    self.class.load_file(influx_file)
                  end
      yield @influx if block_given?
      @influx
    end

    def sqs(&b)
      if @sqs.nil?
        sqs_hash = {}
        sqs_hash[:url] = ENV.fetch('ETL_SQS_QUEUE_URL')
        sqs_hash[:region] = ENV.fetch('ETL_SQS_QUEUE_REGION')
        @sqs = sqs_hash
      end
      yield @sqs if block_given?
      @sqs
    end

    def core_file
      @config_dir + "/core.yml"
    end

    def core(&b)
      get_envvars = is_true_value(ENV.fetch('ETL_CORE_ENVVARS', false))
      @c ||= if get_envvars
                core_hash = {}
                core_hash[:default] = {}
                core_hash[:default][:class_dir] = ENV.fetch('ETL_CLASS_DIR', ::Dir.pwd)

                core_hash[:job] = {}
                core_hash[:job][:class_dir] = ENV.fetch('ETL_JOB_DIR', ::Dir.pwd)
                core_hash[:job][:data_dir] = ENV.fetch('ETL_DATA_DIR')
                core_hash[:job][:retry_max] = 5 # max times retrying jobs
                core_hash[:job][:retry_wait] = 4 # seconds
                core_hash[:job][:retry_mult] = 2.0 # exponential backoff multiplier

                core_hash[:log] = {}
                core_hash[:log][:class] = "ETL::Logger"
                core_hash[:log][:level] = ENV.fetch('ETL_LOG_LEVEL', 'debug')

                core_hash[:database] = database_env_vars

                core_hash[:queue] = {}
                core_hash[:queue][:class] = ENV.fetch('ETL_QUEUE_CLASS', 'ETL::Queue::File')
                core_hash[:queue][:path] = ENV.fetch('ETL_QUEUE_PATH', "/var/tmp/etl_queue")

                core_hash[:metrics] = {}
                core_hash[:metrics][:class] = ENV.fetch('ETL_METRICS_CLASS', "ETL::Metrics")
                core_hash[:metrics][:file] = ENV.fetch('ETL_METRICS_FILE_PATH', '/tmp/etl-metrics.log')
                core_hash[:metrics][:series] = 'etlv2_job_run'

                slack = {}
                slack[:url] = ENV.fetch('ETL_SLACK_URL', nil)
                slack[:channel] = ENV.fetch('ETL_SLACK_CHANNEL', nil)
                slack[:username] = ENV.fetch('ETL_SLACK_USERNAME', nil)
                if !(slack[:url] && slack[:channel] && slack[:username])
                  core_hash[:slack] = slack
                end
                core_hash
             else
                self.class.load_file(core_file)
             end
      yield @c if block_given?
      @c
    end

    # helper for env var values to ensure a string value is actually true
    def is_true_value(v)
      if v.nil?
        return false
      elsif v == false
        return false
      elsif v.to_s.downcase == 'true'
        return true
      end
      return false
    end

    def self.load_file(file)
      ETL::HashUtil::symbolize_keys(Psych.load_file(file))
    end
  end

  def self.config
    Config.instance
  end
end
