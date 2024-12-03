TARGETS=test_deb_version_cmp.sql

test_deb_version_cmp.sql:
	./make_test_deb_version_cmp_sql.bash > $@

all: $(TARGETS)

clean:
	$(RM) $(TARGETS)

.PHONY: all
