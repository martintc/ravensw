#! /usr/bin/env atf-sh

. $(atf_get_srcdir)/test_environment.sh

tests_init \
	repo \
	repo_multiversion

repo_body() {
	touch plop
	touch bla
	atf_check -s exit:0 sh ${RESOURCEDIR}/test_subr.sh new_pkg test test 1 "${TMPDIR}"
	cat >> test.ucl << EOF
files: {
	"${TMPDIR}/plop": ""
	"${TMPDIR}/bla": ""
}
EOF

	atf_check \
		-o empty \
		-e empty \
		-s exit:0 \
		pkg create -M test.ucl

	atf_check \
		-o inline:"Creating repository in .:  done\nPacking files for repository:  done\n" \
		-e empty \
		-s exit:0 \
		pkg repo .

	ln -s test-1.txz test.txz

	atf_check \
		-o inline:"Creating repository in .:  done\nPacking files for repository:  done\n" \
		-e empty \
		-s exit:0 \
		pkg repo .

	if [ `uname -s` = "Darwin" ]; then
		atf_pass
	fi

	nb=$(tar -xf digests.txz -O digests | wc -l)
	atf_check_equal $nb 2

	mkdir Latest
	ln -s test-1.txz Latest/test.txz

	atf_check \
		-o inline:"Creating repository in .:  done\nPacking files for repository:  done\n" \
		-e empty \
		-s exit:0 \
		pkg repo .

	nb=$(tar -xf digests.txz -O digests | wc -l)
	atf_check_equal $nb 2

}

repo_multiversion_body() {
	atf_check -s exit:0 sh ${RESOURCEDIR}/test_subr.sh new_pkg test test 1.0 "${TMPDIR}"
	atf_check -s exit:0 sh ${RESOURCEDIR}/test_subr.sh new_pkg test1 test 1.1 "${TMPDIR}"
	for i in test test1; do
		atf_check pkg create -M $i.ucl
	done

	atf_check \
		-o inline:"Creating repository in .:  done\nPacking files for repository:  done\n" \
		pkg repo .

	cat > pkg.conf << EOF
RAVENSW_DBDIR=${TMPDIR}
REPOS_DIR=[]
repositories: {
	local: { url : file://${TMPDIR} }
}
EOF

	atf_check -o ignore \
		pkg -C ./pkg.conf update

	# Ensure we can pickup the old version
	atf_check -o match:"Installing test-1\.0" \
		pkg -C ./pkg.conf install -y test-1.0

	atf_check -o match:"Upgrading.*to 1\.1" \
		pkg -C ./pkg.conf install -y test

	atf_check -o ignore pkg delete -y test

	atf_check -o match:"Installing test-1\.0" \
		pkg -C ./pkg.conf install -y test-1.0

	atf_check -o match:"Upgrading.*to 1\.1" \
		pkg -C ./pkg.conf upgrade -y

	atf_check -o ignore pkg -C ./pkg.conf delete -y test

	# Ensure the latest version is installed
	atf_check -o match:"Installing test-1.1" \
		pkg -C ./pkg.conf install -y test
}
