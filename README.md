# logstash-output-datadog_logs
*Link to the [Datadog documentation](https://help.datadoghq.com/hc/en-us/articles/115005086506-How-to-Send-Logs-to-Datadog-via-External-Log-Shippers)*

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
        api_key => "<your_datadog_api_key>"
    }
}

```

## Need Help?

If you need any support please contact us at support@datadoghq.com.
