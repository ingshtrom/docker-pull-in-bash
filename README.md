# Docker Pull in Bash

Allowing pulling Docker Images from the Docker Hub Registry without the Docker Engine. 

**This is only for debugging purposes** as the downloaded files are actually thrown away. We only
care about seeing what Curl reports for timing metrics and HTTP response headers so that we can
further debug slow download issues.

# Get Started

If you just want to do a quick test, run `./docker_pull.sh library/ubuntu 16.04
registry-1.docker.io`. This is the same as `docker pull registry-1.docker.io/library/ubuntu:16.04`
or `docker pull ubuntu:16.04`. This image is nice because it isn't too large (multiple gigabytes),
but it does have several layers to test downloading (increases failure chance in intermittent packet
loss scenarios).

If you want to test a large download, run `./docker_pull.sh nvidia/cuda
11.4.2-cudnn8-runtime-ubuntu20.04`. This Docker Image has many layers (each is a file download), but 
one of the layers is 1.3GB, which is a good candidate to test downloads which take longer to
complete.

Lastly, if you have the SHA256 of a layer you want to download, you can use another script in this
repository to do that. To get started, you can run `./layer_download_minimum.sh library/ubuntu 16.04
registry-1.docker.io 952132ac251a8df1f831b354a0b9a4cc7cd460b9c332ed664b4c205db6f22c29` to download
one of the larger layers from the `ubuntu:16.04` Docker Image. To find this SHA256 digest, you can
run the `./docker_pull.sh ...` script and then grep the output for `url_effective`. From there, take
the large 64 character digest and plug that in to the `./layer_download_minimum.sh` script. Here is
an example:
```
$ ./docker_pull.sh library/ubuntu 16.04 registry-1.docker.io
...

$ cat docker_pull_registry-1.docker.io_library-ubuntu_16.04.log| grep 'url_effective'
url_effective: https://production.cloudflare.docker.com/registry-v2/docker/registry/v2/blobs/sha256/58/58690f9b18fca6469a14da4e212c96849469f9b1be6661d2342a4bf01774aa50/data?verify=1637597517-zzngyHN4a%2F7rKhc14eIQvH9NNXo%3D
url_effective: https://production.cloudflare.docker.com/registry-v2/docker/registry/v2/blobs/sha256/b5/b51569e7c50720acf6860327847fe342a1afbe148d24c529fb81df105e3eed01/data?verify=1637597519-jSfFU2EIKSWD5xyENlczVLuKFik%3D
url_effective: https://production.cloudflare.docker.com/registry-v2/docker/registry/v2/blobs/sha256/da/da8ef40b9ecabc2679fe2419957220c0272a965c5cf7e0269fa1aeeb8c56f2e1/data?verify=1637597519-t%2F2LM8fc3NfJB%2Fpox%2BL9AZL5zJQ%3D
url_effective: https://production.cloudflare.docker.com/registry-v2/docker/registry/v2/blobs/sha256/fb/fb15d46c38dcd1ea0b1990006c3366ecd10c79d374f341687eb2cb23a2c8672e/data?verify=1637597520-RPRUBdrSJDiy5kIhZ0vZmuAG8AY%3D

# take one of the above digests and plug it into the `layer_download.minimum.sh` script. In this
# case we are taking the last digest
$ ./layer_download_minimum.sh library/ubuntu 16.04 registry-1.docker.io fb15d46c38dcd1ea0b1990006c3366ecd10c79d374f341687eb2cb23a2c8672e
...
```

**NOTE: the output will be very similar to what is output from the `docker_pull.sh` script, but it
will only download the single blob specified in the 4th argument to the script.**

## Packet Capture

In order to accomplish this, you will need to run multiple terminal sessions on the same client
machine. This can be accomplished by running `tmux` or `ssh`'ing into the same server twice. This
ensures you can capture both tool's output accurately.

First, start `tcpdump` by running `sudo tcpdump host registry-1.docker.io or
production.cloudflare.docker.com or auth.docker.io | tee -a tcpdump.log`. This will capture all packets between the
client (you) and Docker Hub Registry, the auth url for Docker Hub Registry, and the Cloudflare
domain that Docker Hub uses for serving Docker Image layers.

Then, run whatever `docker_pull.sh` or `layer_download_minimum.sh` script you want. After it
completes, press `CTRL-C` in the terminal running `tcpdump` as it needs to be told to stop capturing packets.

Finally, make sure to zip up both `.log` files (one for the download script output, one for the tcpdump
output) if you are providing this as output to a Docker employee.
