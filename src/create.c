/*-
 * Copyright (c) 2011-2015 Baptiste Daroussin <bapt@FreeBSD.org>
 * Copyright (c) 2011-2012 Julien Laffaye <jlaffaye@FreeBSD.org>
 * Copyright (c) 2011 Will Andrews <will@FreeBSD.org>
 * Copyright (c) 2015 Matthew Seaman <matthew@FreeBSD.org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer
 *    in this position and unchanged.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR(S) ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR(S) BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef HAVE_CONFIG_H
#include "pkg_config.h"
#endif

#include <sys/param.h>
#include <sys/queue.h>

#ifdef PKG_COMPAT
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#endif

#include <err.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <pkg.h>
#include <string.h>
#include <unistd.h>
#include <utlist.h>
#include <sysexits.h>

#include "pkgcli.h"

struct pkg_entry {
	struct pkg *pkg;
	struct pkg_entry *next;
	struct pkg_entry *prev;
};
struct pkg_entry *pkg_head = NULL;

void
usage_create(void)
{
	fprintf(stderr, "Usage: pkg create [-Ohnqv] [-f format] [-o outdir] "
		"[-p plist] [-r rootdir] -m metadatadir\n");
	fprintf(stderr, "Usage: pkg create [-Ohnqv] [-f format] [-o outdir] "
		"[-r rootdir] -M manifest\n");
	fprintf(stderr, "       pkg create [-Ohgnqvx] [-f format] [-o outdir] "
		"[-r rootdir] pkg-name ...\n");
	fprintf(stderr, "       pkg create [-Ohnqv] [-f format] [-o outdir] "
		"[-r rootdir] -a\n\n");
	fprintf(stderr, "For more information see 'pkg help create'.\n");
}

static int
pkg_create_matches(int argc, char **argv, match_t match,
    const char * const outdir, bool overwrite)
{
	int i, ret = EPKG_OK, retcode = EPKG_OK;
	struct pkg *pkg = NULL;
	struct pkgdb *db = NULL;
	struct pkgdb_it *it = NULL;
	int query_flags = PKG_LOAD_DEPS | PKG_LOAD_FILES |
	    PKG_LOAD_CATEGORIES | PKG_LOAD_DIRS | PKG_LOAD_SCRIPTS |
	    PKG_LOAD_OPTIONS | PKG_LOAD_LICENSES |
	    PKG_LOAD_USERS | PKG_LOAD_GROUPS | PKG_LOAD_SHLIBS_REQUIRED |
	    PKG_LOAD_PROVIDES | PKG_LOAD_REQUIRES |
	    PKG_LOAD_SHLIBS_PROVIDED | PKG_LOAD_ANNOTATIONS;
	struct pkg_entry *e = NULL, *etmp;
	char pkgpath[MAXPATHLEN];
	const char *format = PKG_FORMAT_EXT;
	bool foundone;

	if (pkgdb_open(&db, PKGDB_DEFAULT) != EPKG_OK) {
		pkgdb_close(db);
		return (EX_IOERR);
	}
	/* XXX: get rid of hardcoded timeouts */
	if (pkgdb_obtain_lock(db, PKGDB_LOCK_READONLY) != EPKG_OK) {
		pkgdb_close(db);
		warnx("Cannot get a read lock on a database, it is locked by another process");
		return (EX_TEMPFAIL);
	}

	for (i = 0; i < argc || match == MATCH_ALL; i++) {
		if (match == MATCH_ALL) {
			printf("Loading the package list...\n");
			if ((it = pkgdb_query(db, NULL, match)) == NULL)
				goto cleanup;
			match = !MATCH_ALL;
		} else
			if ((it = pkgdb_query(db, argv[i], match)) == NULL)
				goto cleanup;

		foundone = false;
		while ((ret = pkgdb_it_next(it, &pkg, query_flags)) == EPKG_OK) {
			if ((e = malloc(sizeof(struct pkg_entry))) == NULL)
				err(1, "malloc(pkg_entry)");
			e->pkg = pkg;
			pkg = NULL;
			DL_APPEND(pkg_head, e);
			foundone = true;
		}
		if (!foundone) {
			warnx("No installed package matching \"%s\" found\n",
			    argv[i]);
			retcode++;
		}

		pkgdb_it_free(it);
		if (ret != EPKG_END)
			retcode++;
	}

	DL_FOREACH_SAFE(pkg_head, e, etmp) {
		DL_DELETE(pkg_head, e);

		if (!overwrite) {
			pkg_snprintf(pkgpath, sizeof(pkgpath), "%S/%n-%v.%S",
			    outdir, e->pkg, e->pkg, format);
			if (access(pkgpath, F_OK) == 0) {
				pkg_printf("%n-%v already packaged, skipping...\n",
				    e->pkg, e->pkg);
				pkg_free(e->pkg);
				free(e);
				continue;
			}
		}
		pkg_printf("Creating package for %n-%v\n", e->pkg, e->pkg);
		if (pkg_create_installed(outdir, e->pkg) !=
		    EPKG_OK)
			retcode++;
		pkg_free(e->pkg);
		free(e);
	}

cleanup:
	pkgdb_release_lock(db, PKGDB_LOCK_READONLY);
	pkgdb_close(db);

	return (retcode);
}

/*
 * options:
 * -M: manifest file
 * -g: globbing
 * -h: pkg name with hash and symlink
 * -m: path to dir where to find the metadata
 * -o: output directory where to create packages by default ./ is used
 * -q: quiet mode
 * -r: rootdir for the package
 * -x: regex
 */

int
exec_create(int argc, char **argv)
{
	match_t		 match = MATCH_EXACT;
	const char	*outdir = NULL;
	const char	*rootdir = NULL;
	const char	*metadatadir = NULL;
	const char	*manifest = NULL;
	char		*plist = NULL;
	int		 ch;
	bool		 overwrite = true;
	bool		 hash = false;


	/* POLA: pkg create is quiet by default, unless
	 * PKG_CREATE_VERBOSE is set in pkg.conf.  This is for
	 * historical reasons. */

	quiet = !pkg_object_bool(pkg_config_get("PKG_CREATE_VERBOSE"));

	struct option longopts[] = {
		{ "all",	no_argument,		NULL,	'a' },
		{ "glob",	no_argument,		NULL,	'g' },
		{ "hash",	no_argument,		NULL,	'h' },
		{ "regex",	no_argument,		NULL,	'x' },
		{ "root-dir",	required_argument,	NULL,	'r' },
		{ "metadata",	required_argument,	NULL,	'm' },
		{ "manifest",	required_argument,	NULL,	'M' },
		{ "no-clobber", no_argument,		NULL,	'n' },
		{ "out-dir",	required_argument,	NULL,	'o' },
		{ "plist",	required_argument,	NULL,	'p' },
		{ "quiet",	no_argument,		NULL,	'q' },
		{ "verbose",	no_argument,		NULL,	'v' },
		{ NULL,		0,			NULL,	0   },
	};

	while ((ch = getopt_long(argc, argv, "+aghxr:m:M:o:np:qv", longopts, NULL)) != -1) {
		switch (ch) {
		case 'a':
			match = MATCH_ALL;
			break;
		case 'g':
			match = MATCH_GLOB;
			break;
		case 'h':
			hash = true;
			break;
		case 'm':
			metadatadir = optarg;
			break;
		case 'M':
			manifest = optarg;
			break;
		case 'n':
			overwrite = false;
			break;
		case 'o':
			outdir = optarg;
			break;
		case 'p':
			plist = optarg;
			break;
		case 'q':
			quiet = true;
			break;
		case 'r':
			rootdir = optarg;
			break;
		case 'v':
			quiet = false;
			break;
		case 'x':
			match = MATCH_REGEX;
			break;
		default:
			usage_create();
			return (EX_USAGE);
		}
	}
	argc -= optind;
	argv += optind;

	if (match != MATCH_ALL && metadatadir == NULL && manifest == NULL &&
	    argc == 0) {
		usage_create();
		return (EX_USAGE);
	}

	if (metadatadir == NULL && manifest == NULL && rootdir != NULL) {
		warnx("Do not specify a rootdir without also specifying "
		    "either a metadatadir or manifest");
		usage_create();
		return (EX_USAGE);
	}

	if (outdir == NULL)
		outdir = "./";

	if (metadatadir == NULL && manifest == NULL) {
		return (pkg_create_matches(argc, argv, match, outdir,
		    overwrite) == EPKG_OK ? EX_OK : EX_SOFTWARE);
	} else if (metadatadir != NULL) {
		return (pkg_create_staged(outdir, rootdir, metadatadir,
		    plist, hash) == EPKG_OK ? EX_OK : EX_SOFTWARE);
	} else  { /* (manifest != NULL) */
		return (pkg_create_from_manifest(outdir, rootdir, manifest,
		    plist) == EPKG_OK ? EX_OK : EX_SOFTWARE);
	}
}

