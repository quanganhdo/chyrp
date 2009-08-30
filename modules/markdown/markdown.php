<?php
    require "lib/markdown.php";

    class Markdown extends Modules {
        public function __init() {
            $this->addAlias("markup_text", "markdownify", 8);
            $this->addAlias("preview", "markdownify", 8);
        }
        static function markdownify($text) {
			if (strpos($text, '<nomarkdown />') !== FALSE) {
				return $text;
			}
            return Markdown($text);
        }
    }
