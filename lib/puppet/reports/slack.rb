require 'puppet'
require 'yaml'
require 'faraday'
require 'json'
require 'uri'

Puppet::Reports.register_report(:slack) do
  desc 'Send notification of puppet run reports to Slack Messaging.'

  def compose(config, message)
      payload = {
        'channel'  => config[:slack_channel],
        'username' => config[:slack_botname],
        'icon_url' => config[:slack_iconurl],
        'text'     => message
      }
      JSON.generate(payload)
  end

  def process

    # setup
    configfile = File.join(Puppet.settings[:confdir], 'slack.yaml')
    unless File.readable?(configfile)
      msg = "Slack report config file #{configfile} is not readable."
      raise(Puppet::ParseError, msg)
    end
    config = YAML.load_file(configfile)
    slack_uri = URI.parse(config[:slack_url])

    # filter
    #return if self.status == 'unchanged'
    #return if self.status == 'changed'
    status_icon = case self.status
                        when 'changed' then ':sparkles:'
                        when 'failed' then ':no_entry:'
                        when 'unchanged' then ':white_check_mark:'
                  end
    # Refer: https://slack.zendesk.com/hc/en-us/articles/202931348-Using-emoji-and-emoticons

    # construct message
    if config[:slack_puppetboard_url]
      message = "#{status_icon} Puppet run for <#{config[:slack_puppetboard_url]}/node/#{self.host}|#{self.host}> #{self.status} at #{Time.now.asctime}."
    else
      message = "#{status_icon} Puppet run for #{self.host} #{self.status} at #{Time.now.asctime}."
    end

    if self.environment != 'production'
      message = message + " Environment was #{self.environment}."
    end

    Puppet.info "Sending status for #{self.host} to Slack."

    conn = Faraday.new(:url => slack_uri.scheme + '://' + slack_uri.host) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    conn.post do |req|
      req.url slack_uri.path
      req.body = "payload=" + compose(config, message)
    end

  end
end
