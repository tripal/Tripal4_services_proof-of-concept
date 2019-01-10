<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class HomeController extends Controller
{
    /**
     * Index controller.
     *
     * @return string
     */
    public function index(Request $request, $limit = 10)
    {
        $content = 'Hello Lumen!';

        $content .= "<br>";

        $content .= "GET Parameter \"genus:\" ".$request->genus;

        $content .= "<br>";

        $content .= "Limit passed by URL: $limit";

        return $content;
    }
}
