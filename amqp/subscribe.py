import json
import pika
import os

cmd_map = {
    "prev": "Previous",
    "next": "Next",
    "play": "Play",
    "pause": "Pause",
    "toggle": "PlayPause",
}

def on_message(channel, method_frame, header_frame, body):
    msg = json.loads(body)
    print(msg)
    if 'cmd' in msg and msg['cmd'] in cmd_map:
        os.system(
            "dbus-send --type=method_call --dest=org.mpris.MediaPlayer2.vlc "
            "/org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.%s" %
            cmd_map[msg['cmd']]
        )
    channel.basic_ack(method_frame.delivery_tag)

credentials = pika.PlainCredentials('guest', 'guest')
parameters = pika.ConnectionParameters('iot.zarybnicky.com', 5672, '/', credentials)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()

channel.queue_declare(queue='chime', exclusive=True)
channel.queue_bind(exchange='amq.topic', queue='chime', routing_key='chime')
channel.basic_consume('chime', on_message)

try:
    channel.start_consuming()
except KeyboardInterrupt:
    channel.stop_consuming()
connection.close()
