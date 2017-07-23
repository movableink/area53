require_relative 'watchers/pod_watcher'
require_relative 'kube_client'
require_relative 'route53_client'
require 'active_support'
require 'active_support/core_ext/object'

class Area53
  def run
    STDOUT.sync = true
    logger = Logger.new(STDOUT)
    logger.info(status: 'setup_log', msg: 'logging using stdout')

    route53_client = Route53Client.new(logger, ENV['HOSTED_ZONE_ID'])

    ServiceWatcher.new(logger, route53_client).run
  end
end
