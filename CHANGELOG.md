## 0.5.3
  - Now is threadsafe: supports shared concurrency.
  - Increase `DD_MAX_BATCH_LENGTH` to `1000`

## 0.5.2
  - Now checks if logstash is being shutdown

## 0.5.1
  - Support using HTTP proxies, adding the `http_proxy` parameter.

## 0.5.0
  - Support Datadog v2 endpoints #28

## 0.4.1
  - Fix HTTP bug when remote server is timing out

## 0.4.0
  - Enable HTTP forwarding for logs
  - Provide an option to disable SSL hostname verification for HTTPS

## 0.3.1
  - Make sure that we can disable retries

## 0.3.0
  - Added support for proxy settings

## 0.2.1
  - Fixed a bug where logs would be truncated at 16kB

## 0.2.0
  - Created an output plugin to send logs to Datadog
