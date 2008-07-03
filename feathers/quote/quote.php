<?php
	class Quote extends Feather {
		public function __construct() {
			$this->setField(array("attr" => "quote",
			                      "type" => "text_block",
			                      "rows" => 5,
			                      "label" => __("Quote", "quote"),
			                      "bookmarklet" => "selection"));
			$this->setField(array("attr" => "source",
			                      "type" => "text_block",
			                      "rows" => 5,
			                      "label" => __("Source", "quote"),
			                      "optional" => true,
			                      "preview" => true,
			                      "bookmarklet" => "page_title"));

			$this->setFilter("quote", "markup_post_text");
			$this->setFilter("source", "markup_post_text");
		}
		public function submit() {
			if (empty($_POST['quote']))
				error(__("Error"), __("Quote can't be empty.", "quote"));

			$post = Post::add(array("quote" => $_POST['quote'],
			                        "source" => $_POST['source']),
			                  $_POST['slug'],
			                  Post::check_url($_POST['slug']));

			redirect($post->redirect);
		}
		public function update() {
			if (empty($_POST['quote']))
				error(__("Error"), __("Quote can't be empty."));

			$post = new Post($_POST['id']);
			$post->update(array("quote" => $_POST['quote'],
			                    "source" => $_POST['source']));
		}
		public function title($post) {
			return $post->title_from_excerpt();
		}
		public function excerpt($post) {
			return $post->quote;
		}
		public function add_dash($text) {
			return preg_replace("/(<p(\s+[^>]+)?>|^)/si", "\\1&mdash; ", $text, 1);
		}
		public function feed_content($post) {
			$body = "<blockquote>\n\t";
			$body.= $post->quote;
			$body.= "\n</blockquote>\n";
			$body.= $post->source;
			return $body;
		}
	}