Pod::Spec.new do |s|
  s.name         = "TCDatabase"
  s.version      = "0.3.10"
  s.summary      = "封装FMDB，支持全文检索、支持条件对象查询、支持定时收回SQLite空间、支持JSON定义表、自动增加表字段等"
  s.homepage     = "https://github.com/ichensheng/TCDatabase"
  s.license      = "Apache"
  s.author             = { "ichensheng" => "cs200521@163.com" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/ichensheng/TCDatabase.git", :tag => "#{s.version}" }
  s.source_files = "TCDatabase/Classes/*.{h,m}"
	s.resources 	 = "TCDatabase/Classes/*.txt"
  s.requires_arc = true
  s.dependency "FMDB/FTS", "~> 2.6.2"
	s.dependency "FCFileManager", "~> 1.0.17"
end
