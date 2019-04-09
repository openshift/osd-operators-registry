# Arguments:
#  1 - github organization / user name
#  2 - github repo name (operator name)
define checkout_operator
	mkdir -p $(SOURCE_DIR); \
	pushd $(SOURCE_DIR); \
	git clone -b master https://github.com/$(1)/$(2).git || (pushd $(2) && git pull && popd); \
	popd
endef