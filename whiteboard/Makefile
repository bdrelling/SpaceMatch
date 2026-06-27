PORT  ?= 7000
IMAGE  = whiteboard
NAME   = whiteboard

build:
	docker build -t $(IMAGE) .

# Foreground (Ctrl-C to stop).
run: build
	docker run --rm -p $(PORT):7000 -v $(CURDIR)/data:/app/data --name $(NAME) $(IMAGE)

# Background, prints the URL to open on the TV/iPad.
up: build
	docker run -d --rm -p $(PORT):7000 -v $(CURDIR)/data:/app/data --name $(NAME) $(IMAGE)
	@echo "Whiteboard up: http://$$(hostname).local:$(PORT)"

stop:
	-docker stop $(NAME)

logs:
	docker logs -f $(NAME)

clean: stop
	-docker rmi $(IMAGE)

.PHONY: build run up stop logs clean
