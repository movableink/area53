class PodWatcher

  def initialize(logger, route53_client)
    @logger = logger
    @kube_client = KubeClient.new(logger, 'v1', 'api')
    @route53_client = route53_client
  end

  def run
    loop do
      @logger.info(watcher: 'Service', status: 'startup', hosted_zone_id: ENV['HOSTED_ZONE_ID'])
      @kube_client.watch_pods.each do |notice|
        begin
          new_notice(notice)
        rescue => ex
          @logger.error(watcher: 'Service', status: 'end_watch', error: ex, backtrace: ex.backtrace.join(' | '))
        end
      end
      @logger.info(watcher: 'Service', status: 'end_all_watch')
    end
  end

  private

  def new_notice(notice)
    action = @route53_client.get_action(notice)
    return if action.nil?

    @logger.info(watcher: 'Service', status: 'new_notice', action: action)
    pod = notice.object

    dns_name = pod.metadata.annotations['dns-name']
    return if dns_name.nil?

    type = 'A'

    pods = @kube_client.get_pods.select do |p|
      p.status.phase == 'Running'
    end

    nodes = pods.map do |p|
      @kube_client.get_node(p.spec.nodeName)
    end

    resource_values = nodes.map do |node|
      node_addresses = node.status.addresses || []
      external_address = node_addresses.find{|i| i.type == 'ExternalIP' }
      raise "Missing node ExternalIP" unless external_address

      external_address.address
    end.uniq

    @logger.info(watcher: 'Service',
                 status: 'change_dns',
                 domain: dns_name,
                 resource_values: resource_values,
                 type: type,
                 action: action)
    @route53_client.change_dns(dns_name, resource_values, type, action)
  end
end
