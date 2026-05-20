# logstash-output-datadog_logs
*Link to the [Datadog documentation](https://docs.datadoghq.com/integrations/logstash/#log-collection)*

DatadogLogs lets you send logs to Datadog based on LogStash events.

## Requirements

The plugin relies upon the `zlib` library for compressing data. Successfully tested with Logstash 7.x, 8.x and 9.x.

## How to install it?

```bash
logstash-plugin install logstash-output-datadog_logs
```


## How to use it?

The `datadog_logs` plugin is configured by default to send logs to a US endpoint over an SSL-encrypted HTTP connection.
The logs are by default batched and compressed.
 
Configure the plugin with your Datadog API key:

```
output {
    datadog_logs {
        api_key => "<DATADOG_API_KEY>"
    }
}
```

To enable TCP forwarding, configure your forwarder with:

```
output {
    datadog_logs {
        api_key => "<DATADOG_API_KEY>"
        host => "http-intake.logs.datadoghq.com"
        port => 443
        use_http => false
    }
}
```

To send logs to a non-US Datadog site, set the `site` parameter. The plugin
derives the correct intake host from `site` automatically:

```
output {
    datadog_logs {
        api_key => "<DATADOG_API_KEY>"
        site => "datadoghq.eu"
    }
}
```

Valid `site` values: `datadoghq.com` (default), `datadoghq.eu`, `us3.datadoghq.com`,
`us5.datadoghq.com`, `ap1.datadoghq.com`, `ddog-gov.com`.

If you set an explicit `host` (and/or `port`), that value wins and `site` is
ignored for that field.

### Configuration properties

|  Property   |  Description                                                             |  Default value |
|-------------|--------------------------------------------------------------------------|----------------|
| **api_key** | The API key of your Datadog platform | nil |
| **site** | Datadog site to forward logs to. The intake host is derived from this value when `host` is not explicitly set. Valid values: `datadoghq.com`, `datadoghq.eu`, `us3.datadoghq.com`, `us5.datadoghq.com`, `ap1.datadoghq.com`, `ddog-gov.com`. | datadoghq.com |
| **host** | Intake host. With `use_http => true` (default), defaults to `http-intake.logs.<site>` when unset. With `use_http => false`, `host` is required. | derived from `site` (HTTP); required (TCP) |
| **port** | Intake port. | 443 |
| **use_ssl** | If true, the agent initializes a secure connection to Datadog. Ensure to update the port if you disable it. | true |
| **max_retries** | The number of retries before the output plugin stops | 5 |
| **max_backoff** | The maximum time waited between each retry in seconds | 30 |
| **use_http** | Enable HTTP forwarding. If you disable it, make sure to update the port to 10516 if use_ssl is enabled or 10514 otherwise.  | true |
| **use_compression** | Enable log compression for HTTP | true |
| **compression_level** | Set the log compression level for HTTP (1 to 9, 9 being the best ratio) | 6 |
| **no_ssl_validation** | Disable SSL validation (useful for proxy forwarding) | false |
| **http_proxy** | Proxy address for http proxies | none |



For additional options, see the [Datadog endpoint documentation](https://docs.datadoghq.com/logs/?tab=eusite#datadog-logs-endpoints)

## Add metadata to your logs

In order to get the best use out of your logs in Datadog, it is important to have the proper metadata associated with them (including hostname, service and source). 
To add those to your logs, add them into your logs with a mutate filter:

```
filter {
  mutate {
    add_field => {
      "host"     => "<HOST>"
      "service"  => "<SERVICE>"
      "ddsource" => "<MY_SOURCE_VALUE>"
      "ddtags"   => "<KEY1:VALUE1>,<KEY2:VALUE2>"
    }
  }
}
```

## Need Help?

If you need any support please contact us at support@datadoghq.com.
