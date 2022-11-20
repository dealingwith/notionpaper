require 'pdfkit'

kit = PDFKit.new(File.read('notion.html'))
kit.to_file("notion.pdf")
