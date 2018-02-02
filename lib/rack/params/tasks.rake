require 'tmpdir'
require 'yard'
require 'yard/rake/yardoc_task'

namespace :docs do
  ROOT_DIR = `git rev-parse --show-toplevel`.strip
  DOC_DIR  = File.join(ROOT_DIR, 'doc')

  YARD::Rake::YardocTask.new(:generate) do |yard|
    yard.options = ["--out", DOC_DIR]
  end

  desc "publish documentation to gh-pages"
  task :publish do
    Dir.mktmpdir('docs-publish') do |tmpdir| 
      `git clone "#{ROOT_DIR}" "#{tmpdir}"`
      Dir.chdir(tmpdir) do |cwd|
        `git checkout gh-pages`
        `rm -rf *`
        `cp -R "#{DOC_DIR}"/* "#{tmpdir}/"`
        `git add .`
        `git commit -am 'published | #{Time.now}'`
        `git push origin gh-pages`
      end
    end
    `git push origin gh-pages`
  end
end
