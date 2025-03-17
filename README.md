# logstash-output-datadog_logs
*Link to the [Datadog documentation](https://docs.datadoghq.com/integrations/logstash/#log-collection)*

DatadogLogs lets you send logs to Datadog based on LogStash events.

## Requirements

The plugin relies upon the `zlib` library for compressing data. Successfully tested with Logstash 6.x, 7.x and 8.x.

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
        host => "intake.logs.datadoghq.com"
        port => 443
        use_http => false
    }
}
```

To send logs to the Datadog's EU HTTP endpoint, override the default `host`

```
output {
    datadog_logs {
        api_key => "<DATADOG_API_KEY>"
        host => "http-intake.logs.datadoghq.eu"
    }
}
```

### Configuration properties

|  Property   |  Description                                                             |  Default value |
|-------------|--------------------------------------------------------------------------|----------------|
| **api_key** | The API key of your Datadog platform | nil |
| **host** | Endpoint when logs are not directly forwarded to Datadog | intake.logs.datadoghq.com |
| **port** | Port when logs are not directly forwarded to Datadog | 443 |
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
