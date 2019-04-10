# Arguments:
#  1 - github organization / user name
#  2 - github repo name (operator name)
define checkout_operator
	mkdir -p $(SOURCE_DIR); \
	if [[ ! -d $(SOURCE_DIR)/$(2) ]]; then \
		git clone -b master https://github.com/$(1)/$(2).git $(SOURCE_DIR)/$(2) ;\
	else \
		if [[  -z "$${SKIP_GITREFRESH}" ]]; then \
			cd $(SOURCE_DIR)/$(2) git reset --hard && git pull --force && cd ../.. ;\
		else \
			echo "SKIP_GITREFRESH set, skipping git refresh for $(1)/$(2)" ;\
		fi ;\
	fi
endef
