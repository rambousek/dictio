root = "#{Dir.getwd}"

bind "unix://#{root}/tmp/puma.sock"
pidfile "#{root}/tmp/pids/puma.pid"
rackup "#{root}/config.ru"
state_path "#{root}/tmp/pids/puma.state"
stdout_redirect "#{root}/logs/stdout", "#{root}/logs/stderr"

workers 2
preload_app! false

require "yabeda/prometheus"
require "yabeda/prometheus/exporter"
require "logger"
activate_control_app "tcp://127.0.0.1:9293", {no_token: true}
plugin :yabeda
plugin :yabeda_prometheus
prometheus_exporter_url "tcp://127.0.0.1:9395/metrics"
before_fork do
  Yabeda.configure!
end
