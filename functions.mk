# Arguments:
#  1 - github organization / user name
#  2 - github repo name (operator name)
define checkout_operator
	mkdir -p $(SOURCE_DIR); \
	if [[ ! -d $(SOURCE_DIR)/$(2) ]]; then \
		git clone -b master https://github.com/$(1)/$(2).git $(SOURCE_DIR)/$(2) ;\
	else \
		if [[  -z "$${SKIP_GITREFRESH}" ]]; then \
			pushd $(SOURCE_DIR)/$(2) && git reset --hard && git pull --force && popd ;\
		else \
			echo "SKIP_GITREFRESH set, skipping git refresh for $(1)/$(2)" ;\
		fi ;\
	fi
endef

# Arguments:
#  1 - directory for env
#  2 - template filename
#  3 - output filename
define process_template
    eval $$($(MAKE) -C $(1) env --no-print-directory); \
    sed -e "s/\#IMAGE_REGISTRY\#/${IMAGE_REGISTRY}/g" \
        -e "s/\#IMAGE_REPOSITORY\#/${IMAGE_REPOSITORY}/g" \
        -e "s/\#IMAGE_NAME\#/${IMAGE_NAME}/g" \
        -e "s/\#CATALOG_NAMESPACE\#/${CATALOG_NAMESPACE}/g" \
        -e "s/\#CHANNEL\#/${CHANNEL}/g" \
        -e "s/\#CATALOG_VERSION\#/${CATALOG_VERSION}/g" \
        -e "s/\#CURRENT_COMMIT\#/${CURRENT_COMMIT}/g" \
        -e "s/\#OPERATOR_NAME\#/$${OPERATOR_NAME}/g" \
        -e "s/\#OPERATOR_NAMESPACE\#/$${OPERATOR_NAMESPACE}/g" \
        $(2) > $(3)
endef

define reset_vars
    for v in ${RESET_VARS}; do \
        unset $${v} ;\
    done
endef