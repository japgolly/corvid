install {
  empty_directory 'test.1'
  empty_directory 'test.2'
  empty_directory 'test.3'
  copy_file 'test.A'
  copy_executable 'test.C'
}

update {|ver|
  case ver
  when 2
    empty_directory 'test.2'
    copy_file 'test.B'
  when 3
    empty_directory 'test.3'
    copy_executable 'test.C'
  end
}
