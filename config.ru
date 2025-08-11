require_relative 'czjapp'
require 'yabeda/prometheus'
use Yabeda::Prometheus::Exporter, path: "/metrics"
run CzjApp

