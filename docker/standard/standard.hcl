target deps {
  dockerfile = "docker/main/Dockerfile"
  platforms = ["linux/amd64"]
  target = "deps"
}

target rootfs {
  dockerfile = "docker/main/Dockerfile"
  platforms = ["linux/amd64"]
  target = "rootfs"
}

target wheels {
  dockerfile = "docker/main/Dockerfile"
  platforms = ["linux/amd64"]
  target = "wheels"
}

target frigate {
  dockerfile = "docker/main/Dockerfile"
  contexts = {
    deps = "target:deps",
    rootfs = "target:rootfs",
    wheels = "target:wheels"
  }
  platforms = ["linux/amd64"]
  target = "frigate"
  outputs = ["type=docker,dest=/tmp/image.tar"]
}
