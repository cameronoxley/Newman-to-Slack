<img src="newman-slack.png" />

# Newman-to-Slack
Runs a Newman test script and outputs the summary to a Slack webhook

####Getting Started:

1. Install [Newman](https://github.com/postmanlabs/newman) ```$ npm install -g newman``` (Requires [Node](https://nodejs.org/en/download/package-manager/))
2. Create a new Slack [incoming webhook](https://my.slack.com/services/new/incoming-webhook/) and copy your webhook URL
3. Download the latest [release]() of Newman to Slack
4. Run `$ ./Newman-to-Slack.sh`

Thats it!

####Usage

```bash
Newman-to-Slack.sh -- Runs a Newman test script and outputs the summary to a Slack webhook

Usage:
    -h 			   show this help text
    -c 	[file]     postman collection to run
    -u 	[url]      postman collection url to run
    -e 	[file]     postman environment to reference
    -g 	[file]     postman global to reference
    -w 	[url] 	   slack webhook to call
    -a 	[command]  additional Newman command
    -S 			   output summary
    -N  		   disable webhook call
    -C  		   disable colorized output to screen, use with -S or -V
    -v  		   current script version
    -V  		   verbose

Where one of: -c [file] or -u [url] is required
```

####Examples

######Run a collection and post the summary to a Slack channel

```bash
$ ./Newman-to-Slack.sh -c mycollection.json.postman_collection -w https://hooks.slack.com/services/my/private/url
```

######Run a url collection and post the summary to a Slack channel

```bash
$ ./Newman-to-Slack.sh -u https://www.getpostman.com/collections/cb208e7e64056f5294e5 -w https://hooks.slack.com/services/my/private/url
```

######Run a collection with a custom environment and post the summary to a Slack channel

```bash
$ ./Newman-to-Slack.sh -c mycollection.json.postman_collection -e myenvironment.postman_environment -w https://hooks.slack.com/services/my/private/url
```
######Run a collection with a custom Newman command and post the summary to a Slack channel

```bash
$ ./Newman-to-Slack.sh -c mycollection.json.postman_collection -e myenvironment.postman_environment -w https://hooks.slack.com/services/my/private/url -a "-R -E 'output.html'"
```

######Run a collection, only display Newman summary (without posting to Slack) and disable colourised output

```bash
$ ./Newman-to-Slack.sh -c mycollection.json.postman_collection -N -C
```


<sub>Thanks to [@kiichi](https://github.com/kiichi) for the [original gist](https://gist.github.com/kiichi/938ea910f88bf43b0db1)</sub>
