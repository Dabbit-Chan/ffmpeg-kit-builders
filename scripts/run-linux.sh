#!/bin/bash

# shellcheck disable=SC2317,SC1091,SC1090,SC2120

build_libjsoncpp() {
  activate_meson
	change_dir "$src_dir"
	do_git_checkout https://github.com/open-source-parsers/jsoncpp jsoncpp
	change_dir "$src_dir/jsoncpp"
  local meson_options="--prefix=$dependency_install_prefix -Ddefault_library=static"
	do_meson "$meson_options" "setup build"
	do_ninja_and_ninja_install
	change_dir "$src_dir"
}
