outpath = ./docs/
target = Initializable

.PHONY: docs

docs:
	rm -rf $(outpath)
	swift package --allow-writing-to-directory $(outpath) \
		generate-documentation --target $(target) --disable-indexing \
		--output-path $(outpath) \
		--transform-for-static-hosting \
		--hosting-base-path $(target)
