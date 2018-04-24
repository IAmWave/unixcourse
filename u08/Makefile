Sources=$(wildcard *.jpg)
Temp=$(addprefix thumbs/,$(Sources))
AllThumbs=$(Temp:.jpg=.thumb.jpg)

all: index.html

index.html: $(AllThumbs)
	./build_album.sh >index.html

thumbs/%.thumb.jpg: %.jpg thumbs/
	convert $< -resize 100x100 $@

thumbs/:
	mkdir -p thumbs

clean:
	rm thumbs/*.thumb.jpg
	rm index.html
