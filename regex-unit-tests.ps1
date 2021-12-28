

# This uses the Pester framework. Note you have to update to Pester
# version 5.x (Win10 comes with Pester 3.x which has different syntax)
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

}





