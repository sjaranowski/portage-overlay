# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
#
# File by Szymon Jaranowski (szymon.jaranowski@gmail.com);
# based (heavily) on ebuilds by:
# * Pacho Ramos (official Gentoo repository)
# * flow ("flow" repository visible from layman)
#
# $$

EAPI=5

AUTOTOOLS_AUTORECONF=true

inherit autotools-utils flag-o-matic eutils git-2 wxwidgets user systemd

DESCRIPTION="The Berkeley Open Infrastructure for Network Computing"
HOMEPAGE="http://boinc.ssl.berkeley.edu/"
SRC_URI=""

EGIT_REPO_URI="git://boinc.berkeley.edu/boinc-v2.git"
EGIT_COMMIT="client_release/7.4/7.4.27"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS=""
IUSE="X static-libs"

RDEPEND="
	!sci-misc/boinc-bin
	!app-admin/quickswitch
	>=app-misc/ca-certificates-20080809
	dev-libs/openssl
	net-misc/curl[ssl,-gnutls(-),-nss(-),curl_ssl_openssl(+)]
	sys-apps/util-linux
	sys-libs/zlib
	X? (
		dev-db/sqlite:3
		media-libs/freeglut
		sys-libs/glibc:2.2
		virtual/jpeg
		x11-libs/gtk+:2
		>=x11-libs/libnotify-0.7
		x11-libs/wxGTK:3.0[X,opengl]
	)
"
DEPEND="${RDEPEND}
	sys-devel/gettext
	app-text/docbook-xml-dtd:4.4
	app-text/docbook2X
"

AUTOTOOLS_IN_SOURCE_BUILD=1

src_prepare() {
	# prevent bad changes in compile flags, bug 286701
	sed -i -e "s:BOINC_SET_COMPILE_FLAGS::" configure.ac || die "sed failed"

	autotools-utils_src_prepare
}

src_configure() {
	local wxconf=""

	# add gtk includes
	append-flags "$(pkg-config --cflags gtk+-3.0)"

	# look for wxGTK
	if use X; then
		WX_GTK_VER="3.0"
		need-wxwidgets unicode
		wxconf+=" --with-wx-config=${WX_CONFIG}"
	else
		wxconf+=" --without-wxdir"
	fi

	# Don't just use --disable-server as recommended at
	# https://boinc.berkeley.edu/trac/wiki/BuildSystem Instead use
	# --enable-client and --disable-server and respect the X use flag
	local myeconfargs=(
		--enable-client
		--disable-server
		--enable-dynamic-client-linkage
		--disable-static
		--enable-unicode
		--with-ssl
		$(use_with X x)
		$(use_enable X manager)
		${wxconf}
	)
	autotools-utils_src_configure
}

src_install() {
	autotools-utils_src_install

	dodir /var/lib/${PN}/
	keepdir /var/lib/${PN}/

	if use X; then
		newicon "${S}"/packages/generic/sea/${PN}mgr.48x48.png ${PN}.png || die
		make_desktop_entry boincmgr "BOINC monitor and control utility" "BOINC monitor and control utility" "Math;Science" "Path=/var/lib/${PN}"
	fi

	# cleanup cruft
	rm -rf "${ED}"/etc/

	newinitd "${FILESDIR}"/${PN}.init ${PN}
	newconfd "${FILESDIR}"/${PN}.conf ${PN}
	systemd_dounit "${FILESDIR}"/${PN}.service
}

pkg_preinst() {
	enewgroup ${PN}
	# note this works only for first install so we have to
	# elog user about the need of being in video group
	
	enewuser ${PN} -1 -1 /var/lib/${PN} "${PN},video"
}

pkg_postinst() {
	echo
	elog "You are using the source compiled version of ${PN}."
	use X && elog "The graphical manager can be found at /usr/bin/${PN}mgr"
	elog
	elog "You need to attach to a project to do anything useful with ${PN}."
	elog "You can do this by running /etc/init.d/${PN} attach"
	elog "The howto for configuration is located at:"
	elog "http://boinc.berkeley.edu/wiki/Anonymous_platform"
	elog
	# Add warning about the new password for the client, bug 121896.
	if use X; then
		elog "If you need to use the graphical manager the password is in:"
		elog "/var/lib/${PN}/gui_rpc_auth.cfg"
		elog "Where /var/lib/ is default RUNTIMEDIR, that can be changed in:"
		elog "/etc/conf.d/${PN}"
		elog "You should change this password to something more memorable (can be even blank)."
		elog "Remember to launch init script before using manager. Or changing the password."
		elog
		elog "To be able to use CUDA you should add boinc user to video group."
		elog "Run as root:"
		elog "gpasswd -a boinc video"
	fi
}
