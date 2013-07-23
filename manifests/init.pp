# Debian/nexenta specific build module
#
# build::install { 'top':
#   download => 'http://www.unixtop.org/dist/top-3.7.tar.gz',
#   creates  => '/usr/local/bin/top',
# }

define build::install (
  $download,
  $creates,
  $pkg_folder='',
  $pkg_format="tar",
  $pkg_extension="",
  $buildoptions="",
  $extractorcmd="",
  $make_cmd="",
  $wget_params="",
  $rm_build_folder=true) {
  
  Exec {
    creates => $creates,
  }
  
  $cwd    = "/usr/local/src"
  
  $unzip  = "/usr/bin/unzip"
  $tar    = "/bin/tar"
  $bunzip = "/usr/bin/bunzip2"
  $gunzip = "/usr/bin/gunzip"
  
  $filename = basename($download)
  
  $extension = $pkg_format ? {
    zip     => ".zip",
    bzip    => ".tar.bz2",
    tar     => ".tar.gz",
    default => $pkg_extension,
  }
  
  $foldername = $pkg_folder ? {
    ''      => gsub($filename, $extension, ""),
    default => $pkg_folder,
  }
  
  $extractor = $pkg_format ? {
    zip     => "$unzip -q -d $cwd $cwd/$filename",
    bzip    => "$bunzip -c $cwd/$filename | $tar -xf -",
    tar     => "$gunzip < $cwd/$filename | $tar -xf -",
    default => $extractorcmd,
  }

  $make = $make_cmd ? {
    '' => '/usr/bin/make && /usr/bin/make install',
    default => $make_cmd,
  }
  
  exec { "download-$name":
    cwd     => "$cwd",
    command => "/usr/bin/wget -q $download $wget_params",
    timeout => 120, # 2 minutes
  }
  
  exec { "extract-$name":
    cwd     => "$cwd",
    command => "$extractor",
    timeout => 120, # 2 minutes
    require => Exec["download-$name"],
  }
  
  exec { "config-$name":
    cwd     => "$cwd/$foldername",
    command => "$cwd/$foldername/configure $buildoptions",
    timeout => 120, # 2 minutes
    require => Exec["extract-$name"],
    onlyif => "/bin/ls $cwd/$foldername/configure 2> /dev/null",

  }
  
  exec { "make-install-$name":
    cwd     => "$cwd/$foldername",
    command => "$make",
    timeout => 600, # 10 minutes
    require => Exec["config-$name"],
  }
  
  # remove build folder
  case $rm_build_folder {
    true: {
      exec { "remove-$name-build-folder":
        cwd     => "$cwd",
        command => "/bin/rm -rf $cwd/$foldername",
        require => Exec["make-install-$name"],
        creates => '',
        onlyif => "/bin/ls $cwd/$foldername/ 2> /dev/null",
      } # exec
    } # true
  } # case
  
}

define build::requires ( $ensure='installed', $package ) {
  if defined( Package[$package] ) {
    debug("$package already installed")
  } else {
    package { $package: ensure => $ensure }
  }
}
