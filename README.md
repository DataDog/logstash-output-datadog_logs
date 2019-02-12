# logstash-output-datadog_logs
*Link to the [Datadog documentation](https://docs.datadoghq.com/integrations/logstash/#log-collection)*

DatadogLogs lets you send logs to Datadog based on LogStash events.

## How to install it?

```bash
logstash-plugin install logstash-output-datadog_logs
```


## How to use it?

Configure `datadog_logs` plugin with your Datadog API key:

```
output {
    datadog_logs {
        api_key => "<DATADOG_API_KEY>"
    }
}
```

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

### Properties

To go deeper on the plugin configuration.
Here is the full list of parameters that you can use to configure the logstash plugin:


|  Property   |  Description                                                             |  Default value |
|-------------|--------------------------------------------------------------------------|----------------|
| **api_key** | The API key of your Datadog platform | nil |
| **host** | Proxy endpoint when logs are not directly forwarded to Datadog | intake.logs.datadoghq.com |
| **port** | Proxy port when logs are not directly forwarded to Datadog | 10516 |
| **use_ssl** | If true, the agent initializes a secure connection to Datadog. In clear TCP otherwise.  | true |
| **max_retries** | The number of retries before the output plugin stops | 5 |

The default configuration listed above is for US-based sites that will send logs over an SSL-encrypted connection. For EU sites and unencrypted connection options, see the [Datadog endpoint documentation](https://docs.datadoghq.com/logs/?tab=eusite#datadog-logs-endpoints).

## Need Help?

If you need any support please contact us at support@datadoghq.com.
