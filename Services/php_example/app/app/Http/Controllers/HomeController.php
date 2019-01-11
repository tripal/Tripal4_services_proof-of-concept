<?php

namespace App\Http\Controllers;

class HomeController extends Controller
{
    /**
     * Index controller.
     *
     * @return array
     */
    public function index()
    {
        $app = app();

        return $app->router->getRoutes();
    }
}
