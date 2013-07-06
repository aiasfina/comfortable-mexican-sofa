module ComfortableMexicanSofa::Fixture::Page
  class Importer < ComfortableMexicanSofa::Fixture::Importer
    
    def import!(path = self.path, parent = nil)
      Dir["#{path}*/"].each do |path|
        slug = path.split('/').last
        
        page = if parent
          parent.children.find_or_initialize_by_slug(slug)
        else
          site.pages.root || site.pages.new(:slug => slug)
        end
        
        # setting attributes
        if File.exists?(attrs_path = File.join(path, 'attributes.yml'))
          if fresh_fixture?(page, attrs_path)
            attrs = get_attributes(attrs_path)
            
            page.label        = attrs[:label]
            page.layout       = site.layouts.find_by_identifier(attrs[:layout]) || parent.try(:layout)
            page.is_published = attrs[:is_published].nil?? true : attrs[:is_published]
            page.position     = attrs[:position] if attributes[:position]
          end
        end
        
        # setting content
        blocks_to_clear = page.blocks.collect(&:identifier)
        blocks_attributes = [ ]
        Dir.glob("#{path}/*.html").each do |block_path|
          identifier = block_path.split('/').last.gsub(/\.html$/, '')
          blocks_to_clear.delete(identifier)
          if fresh_fixture?(page, block_path)
            blocks_attributes << {
              :identifier => identifier,
              :content    => File.open(file_path).read
            }
          end
        end
        
        blocks_to_clear.each do |identifier|
          blocks_attributes << {
            :identifier => identifier,
            :content    => nil
          }
        end
        
        page.blocks_attributes = blocks_attributes if blocks_attributes.present?
        
        # saving
        if page.changed?
          if page.save
            self.fixture_ids << page.id
            ComfortableMexicanSofa.logger.warn("[Fixtures] Saved Page {#{page.identifier}}")
          else
            ComfortableMexicanSofa.logger.warn("[Fixtures] Failed to save Page {#{page.errors.inspect}}")
          end
        end
        
        import!(path, page)
      end
      
      # cleaning up
      unless parent
        self.site.pages.where('id NOT IN (?)', self.fixture_ids).each{ |s| s.destroy }
        ComfortableMexicanSofa.logger.warn('Imported Pages!')
      end
    end
  end

  class Exporter < ComfortableMexicanSofa::Fixture::Exporter
    def export!
      prepare_folder!(self.path)
      
      self.site.pages.each do |page|
        page.slug = 'index' if page.slug.blank?
        page_path = File.join(path, page.ancestors.reverse.collect{|p| p.slug.blank?? 'index' : p.slug}, page.slug)
        prepare_folder!(page_path)

        open(File.join(page_path, 'attributes.yml'), 'w') do |f|
          f.write({
            'label'         => page.label,
            'layout'        => page.layout.try(:identifier),
            'parent'        => page.parent && (page.parent.slug.present?? page.parent.slug : 'index'),
            'target_page'   => page.target_page.try(:slug),
            'is_published'  => page.is_published,
            'position'      => page.position
          }.to_yaml)
        end
        page.blocks_attributes.each do |block|
          open(File.join(page_path, "#{block[:identifier]}.html"), 'w') do |f|
            f.write(block[:content])
          end
        end
      end
    end
  end
end