import json
import pika
import sys

cmd = "next"
if len(sys.argv) >= 2:
    cmd = sys.argv[1]

credentials = pika.PlainCredentials('guest', 'guest')
parameters = pika.ConnectionParameters('iot.zarybnicky.com', 5672, '/', credentials)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()
channel.basic_publish(
    exchange='amq.topic',
    routing_key='chime',
    body=json.dumps({ "cmd": cmd }),
)
connection.close()
