require 'rails_helper'

describe Unfurler::Html do
  subject { described_class.new(html).perform }

  context 'full example file' do
    let(:html) { file_fixture("kobe-hatoba-blue-all-attributes.html") }

    it 'extracts the url' do
      expect(subject.url).to eq('https://mountainofink.com/blog/kobe-hatoba-blue')
    end

    it 'extracts the title' do
      expect(subject.title).to eq('Ink Review #1699: Kobe 02 Hatoba Blue — Mountain of Ink')
    end

    it 'extracts the description' do
      expect(subject.description).to eq('Kobe is a brand I come back to again and again, just because I love them so much. Today let’s look at  Kobe 02 Hatoba Blue . You can find this ink for sale at most retailers including  Vanness Pens .')
    end

    it 'extracts the image' do
      expect(subject.image).to eq('http://static1.squarespace.com/static/591a04711e5b6c3701808c11/591a07702994cadba4aeb479/61a67ef965f99c77610c2c39/1638384095123/nk-hatoba-blue-w-1.jpg?format=1500w')
    end

    it 'extracts the author' do
      expect(subject.author).to eq('Kelli McCown')
    end
  end

  context 'only og data' do
    let(:html) { file_fixture("kobe-hatoba-blue-og-attributes.html") }

    it 'extracts the url' do
      expect(subject.url).to eq('https://mountainofink.com/blog/kobe-hatoba-blue')
    end

    it 'extracts the title' do
      expect(subject.title).to eq('Ink Review #1699: Kobe 02 Hatoba Blue — Mountain of Ink')
    end

    it 'extracts the description' do
      expect(subject.description).to eq('Kobe is a brand I come back to again and again, just because I love them so much. Today let’s look at  Kobe 02 Hatoba Blue . You can find this ink for sale at most retailers including  Vanness Pens .')
    end

    it 'extracts the image' do
      expect(subject.image).to eq('http://static1.squarespace.com/static/591a04711e5b6c3701808c11/591a07702994cadba4aeb479/61a67ef965f99c77610c2c39/1638384095123/nk-hatoba-blue-w-1.jpg?format=1500w')
    end
  end

  context 'only itemprops' do
    let(:html) { file_fixture("kobe-hatoba-blue-itemprop-attributes.html") }

    it 'extracts the url' do
      expect(subject.url).to eq('https://mountainofink.com/blog/kobe-hatoba-blue')
    end

    it 'extracts the title' do
      expect(subject.title).to eq('Ink Review #1699: Kobe 02 Hatoba Blue — Mountain of Ink')
    end

    it 'extracts the description' do
      expect(subject.description).to eq('Kobe is a brand I come back to again and again, just because I love them so much. Today let’s look at  Kobe 02 Hatoba Blue . You can find this ink for sale at most retailers including  Vanness Pens .')
    end

    it 'extracts the image' do
      expect(subject.image).to eq('http://static1.squarespace.com/static/591a04711e5b6c3701808c11/591a07702994cadba4aeb479/61a67ef965f99c77610c2c39/1638384095123/nk-hatoba-blue-w-1.jpg?format=1500w')
    end
  end

  context 'only twitter data' do
    let(:html) { file_fixture("kobe-hatoba-blue-twitter-attributes.html") }

    it 'extracts the url' do
      expect(subject.url).to eq('https://mountainofink.com/blog/kobe-hatoba-blue')
    end

    it 'extracts the title' do
      expect(subject.title).to eq('Ink Review #1699: Kobe 02 Hatoba Blue — Mountain of Ink')
    end

    it 'extracts the description' do
      expect(subject.description).to eq('Kobe is a brand I come back to again and again, just because I love them so much. Today let’s look at  Kobe 02 Hatoba Blue . You can find this ink for sale at most retailers including  Vanness Pens .')
    end

    it 'extracts the image' do
      expect(subject.image).to eq('http://static1.squarespace.com/static/591a04711e5b6c3701808c11/591a07702994cadba4aeb479/61a67ef965f99c77610c2c39/1638384095123/nk-hatoba-blue-w-1.jpg?format=1500w')
    end
  end

  context 'only HTML data' do
    let(:html) { file_fixture("kobe-hatoba-blue-html-attributes.html") }

    it 'extracts the url' do
      expect(subject.url).to eq('https://mountainofink.com/blog/kobe-hatoba-blue')
    end

    it 'extracts the title' do
      expect(subject.title).to eq('Ink Review #1699: Kobe 02 Hatoba Blue — Mountain of Ink')
    end

    it 'extracts the description' do
      expect(subject.description).to eq('Kobe is a brand I come back to again and again, just because I love them so much. Today let’s look at  Kobe 02 Hatoba Blue . You can find this ink for sale at most retailers including  Vanness Pens .')
    end

    it 'extracts the image' do
      expect(subject.image).to eq('http://static1.squarespace.com/static/591a04711e5b6c3701808c11/591a07702994cadba4aeb479/61a67ef965f99c77610c2c39/1638384095123/nk-hatoba-blue-w-1.jpg?format=1500w')
    end
  end

  context 'no data present' do
    let(:html) { '' }

    it 'does not fail when the url cannot be found' do
      expect(subject.url).to eq(nil)
    end

    it 'does not fail when the title cannot be found' do
      expect(subject.title).to eq(nil)
    end

    it 'does not fail when the title cannot be found' do
      expect(subject.description).to eq(nil)
    end

    it 'does not fail when the title cannot be found' do
      expect(subject.image).to eq(nil)
    end

    it 'does not fail when the author cannot be found' do
      expect(subject.author).to eq(nil)
    end
  end

  context 'youtube' do
    let(:html) { file_fixture('youtube.html') }

    it 'extracts the url' do
      expect(subject.url).to eq('https://www.youtube.com/watch?v=1aKR9th0sDo')
    end

    it 'extracts the title' do
      expect(subject.title).to eq('Waterman Serenity Blue | Why Did I Wait So Long To Try This Ink')
    end

    it 'extracts the description' do
      expect(subject.description).to eq("#AtelierLusso #SerenityBlue #EndlessWorks #WatermanIt's an oldie but a goodie and this week it's up for review. Join me as I take a look at Waterman Serenity...")
    end

    it 'extracts the image' do
      expect(subject.image).to eq('https://i.ytimg.com/vi/1aKR9th0sDo/maxresdefault.jpg')
    end

    it 'extracts the author' do
      expect(subject.author).to eq('The Inked Well')
    end
  end

  context 'anderson' do
    let(:html) { file_fixture('anderson.html') }

    it 'extracts the url' do
      expect(subject.url).to eq('https://blog.andersonpens.com/sailor-miruai-ink-review/')
    end

    it 'extracts the title' do
      expect(subject.title).to eq('thINKthursday – Sailor Miruai Ink Review | Anderson Pens Blog')
    end

    it 'extracts the description' do
      expect(subject.description).to eq(nil)
    end

    it 'extracts the image' do
      expect(subject.image).to eq('http://blog.andersonpens.com/wp-content/uploads/2016/05/InkReview_Sailor_Miruai_Full.jpg')
    end

    it 'extracts the author' do
      expect(subject.author).to eq(nil)
    end
  end
end
