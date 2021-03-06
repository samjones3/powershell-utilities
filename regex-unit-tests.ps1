

# This uses the Pester framework. Note you have to update to Pester
# version 5.x (Win10 comes with Pester 3.x which has different syntax)

# Note that literals in non latin letters must be in double quotes
# (this is a powershell thing). Also, the .ps1 must have a BOM

# Cool tip! With pester v5.x and VSCode in powershell mode, 
# the editor has a little "run tests" link above the Describe
# keyword, so you can run tests right in the editor... sweet!

Describe "regex validation suite" {
    It "first test" {
        $string = 'test'
        $string -match '^.*[\u0590-\u05ea].+$' | Should -Be $false
    }
    It "second" {
        $string = "עברית" 
        $string -match '^.*[\u0590-\u05ea].+$' |Should -Be $true
        
    }
    It "third" {
        $string = "test- and cheese עברית" 
        $string -match '^.*[\u0590-\u05ea].+$' | Should -Be $true
        
    }
    It "fourth" {
        $string = "עdest-chees ברית" 
        $string -match '^.*[\u0590-\u05ea].+$' | Should -Be $true
        
        $string = "עברית for the win.pse"
        $string -match '^.*[\u0590-\u05ea].+$' | Should -Be $true
    }
    It "filenames - hebrew" {

        "pronunciation_he_לְבַטֵּל.mp3" -match '^.*[\u0590-\u05ea].+$' | Should -Be $true
        "pronunciation_he_לְבַטֵּל." -match '^.*[\u0590-\u05ea].+$' | Should -Be $true

        "pronunciation_he_לְבַטֵּל" -match '^.*[\u0590-\u05ea].+$' | Should -Be $true
        "הייתי רוצה להסב לו קצת כאב.mp4" -match '^.*[\u0590-\u05ea].+$' | Should -Be $true
    }    
    It "filenames - non-hebrew" {

        "President's Report 12.14.21.pdf" -match '^.*[\u0590-\u05ea].+$' | Should -Be $false
        "Minutes Board Meeting July_13_2021 7.13.21.pdf" -match '^.*[\u0590-\u05ea].+$' | Should -Be $false

        
    }

    
}





