# Code written by: Diane Feddema dfeddema@redhat.com
# modified for this project by Selbi Nuryyeva selbi@redhat.com
# to run the code: python matmul.py gpu 1500
# can modify: gpu/cpu and shape of matrix (ie. 1500)

import sys
import numpy as np
import tensorflow as tf
from datetime import datetime

# Original code was written for Tensorflow 1.x. To run on 2.x, eager execution needs to be disabled.
tf.compat.v1.disable_eager_execution()

device_name = sys.argv[1]  # Choose device from cmd line. Options: gpu or cpu
shape = (int(sys.argv[2]), int(sys.argv[2]))
if device_name == "gpu":
    device_name = "/gpu:0"
else:
    device_name = "/cpu:0"

with tf.device(device_name):
    random_matrix = tf.random.uniform(shape=shape, minval=0, maxval=1)
    dot_operation = tf.matmul(random_matrix, tf.transpose(random_matrix))
    sum_operation = tf.reduce_sum(dot_operation)


startTime = datetime.now()
with tf.compat.v1.Session(config=tf.compat.v1.ConfigProto(log_device_placement=True)) as session:
        result = session.run(sum_operation)
        print(result)

# It can be hard to see the results on the terminal with lots of output -- add some newlines to improve readability.
print("\n" * 5)
print("Shape:", shape, "Device:", device_name)
print("Time taken:", datetime.now() - startTime)

print("\n" * 5)
