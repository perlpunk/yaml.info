build: gh-pages
	-rm -r gh-pages/*
	cp -rp static/* gh-pages/
	perl bin/build.pl

gh-pages:
	git branch gh-pages --track origin/gh-pages
	git worktree add gh-pages gh-pages

lint:
	yamllint -c .yamllint.yaml .
