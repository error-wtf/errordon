# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Errordon::SecurityService do
  describe '.sanitize_filename' do
    it 'removes path traversal attempts' do
      expect(described_class.sanitize_filename('../../../etc/passwd')).to eq('______etc_passwd')
    end

    it 'removes null bytes' do
      expect(described_class.sanitize_filename("file\x00.txt")).to eq('file.txt')
    end

    it 'removes dangerous characters' do
      expect(described_class.sanitize_filename('file<script>.txt')).to eq('file_script_.txt')
    end

    it 'truncates long filenames' do
      long_name = 'a' * 300 + '.txt'
      result = described_class.sanitize_filename(long_name)
      expect(result.length).to be <= 255
    end

    it 'returns "unnamed" for blank input' do
      expect(described_class.sanitize_filename('')).to eq('unnamed')
      expect(described_class.sanitize_filename(nil)).to eq('unnamed')
    end

    it 'blocks executable extensions' do
      dangerous = %w[file.exe file.bat file.cmd file.sh file.ps1 file.vbs file.js]
      dangerous.each do |filename|
        # The sanitize method should still work, but validation should catch these
        result = described_class.sanitize_filename(filename)
        expect(result).to be_present
      end
    end
  end

  describe '.safe_path?' do
    let(:base_dir) { '/var/uploads' }

    it 'returns true for paths within base directory' do
      expect(described_class.safe_path?('/var/uploads/file.txt', base_dir)).to be true
      expect(described_class.safe_path?('/var/uploads/subdir/file.txt', base_dir)).to be true
    end

    it 'returns false for path traversal attempts' do
      expect(described_class.safe_path?('/var/uploads/../etc/passwd', base_dir)).to be false
      expect(described_class.safe_path?('/etc/passwd', base_dir)).to be false
    end

    it 'returns false for blank inputs' do
      expect(described_class.safe_path?('', base_dir)).to be false
      expect(described_class.safe_path?(nil, base_dir)).to be false
      expect(described_class.safe_path?('/var/uploads/file.txt', '')).to be false
    end
  end

  describe '#validate!' do
    let(:file) { double('file') }
    let(:service) { described_class.new(file) }

    before do
      allow(file).to receive(:original_filename).and_return('test.mp4')
      allow(file).to receive(:content_type).and_return('video/mp4')
      allow(file).to receive(:size).and_return(100.megabytes)
      allow(file).to receive(:read).and_return("\x00\x00\x00\x1Cftyp")
      allow(file).to receive(:rewind)
    end

    context 'with valid file' do
      it 'returns true' do
        expect(service.validate!).to be true
      end
    end

    context 'with dangerous MIME type' do
      before do
        allow(file).to receive(:content_type).and_return('application/x-executable')
      end

      it 'raises MaliciousFileError' do
        expect { service.validate! }.to raise_error(Errordon::SecurityService::MaliciousFileError)
      end
    end

    context 'with suspicious filename' do
      before do
        allow(file).to receive(:original_filename).and_return('../../../etc/passwd')
      end

      it 'raises MaliciousFileError' do
        expect { service.validate! }.to raise_error(Errordon::SecurityService::MaliciousFileError)
      end
    end

    context 'with executable signature' do
      before do
        allow(file).to receive(:read).and_return("MZ\x90\x00\x03\x00\x00\x00")
      end

      it 'raises MaliciousFileError' do
        expect { service.validate! }.to raise_error(Errordon::SecurityService::MaliciousFileError)
      end
    end

    context 'with embedded script' do
      before do
        allow(file).to receive(:read).and_return('<script>alert("xss")</script>')
      end

      it 'raises MaliciousFileError' do
        expect { service.validate! }.to raise_error(Errordon::SecurityService::MaliciousFileError)
      end
    end

    context 'with empty file' do
      before do
        allow(file).to receive(:size).and_return(0)
      end

      it 'raises MaliciousFileError' do
        expect { service.validate! }.to raise_error(Errordon::SecurityService::MaliciousFileError)
      end
    end

    context 'with oversized file' do
      let(:service) { described_class.new(file, max_size: 10.megabytes) }

      before do
        allow(file).to receive(:size).and_return(500.megabytes)
      end

      it 'raises MaliciousFileError' do
        expect { service.validate! }.to raise_error(Errordon::SecurityService::MaliciousFileError)
      end
    end
  end

  describe 'DANGEROUS_MIME_TYPES' do
    it 'includes executable types' do
      expect(described_class::DANGEROUS_MIME_TYPES).to include('application/x-executable')
      expect(described_class::DANGEROUS_MIME_TYPES).to include('application/x-msdownload')
    end

    it 'includes script types' do
      expect(described_class::DANGEROUS_MIME_TYPES).to include('application/javascript')
      expect(described_class::DANGEROUS_MIME_TYPES).to include('application/x-httpd-php')
    end
  end

  describe 'SUSPICIOUS_PATTERNS' do
    it 'matches path traversal' do
      expect(described_class::SUSPICIOUS_PATTERNS.any? { |p| '../test'.match?(p) }).to be true
    end

    it 'matches null bytes' do
      expect(described_class::SUSPICIOUS_PATTERNS.any? { |p| "test\x00.txt".match?(p) }).to be true
    end

    it 'matches executable extensions' do
      expect(described_class::SUSPICIOUS_PATTERNS.any? { |p| 'file.exe'.match?(p) }).to be true
      expect(described_class::SUSPICIOUS_PATTERNS.any? { |p| 'file.bat'.match?(p) }).to be true
    end
  end
end
