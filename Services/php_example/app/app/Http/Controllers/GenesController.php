<?php

namespace App\Http\Controllers;

use App\Gene;
use Illuminate\Http\Request;

class GenesController extends Controller
{
    /**
     * @return mixed
     */
    public function index()
    {
        return Gene::paginate(10);
    }

    /**
     * @param \Illuminate\Http\Request $request
     * @throws \Illuminate\Validation\ValidationException
     */
    public function create(Request $request)
    {
        $this->validate($request, [
            'name' => 'required|unique:genes,name',
            'type' => 'required|in:mRNA,gene',
            'residue' => 'nullable',
        ]);

        $gene = Gene::create([
            'name' => $request->name,
            'type' => $request->type,
            'residue' => $request->residue,
        ]);

        return $gene;
    }

    /**
     * @param $id
     * @return mixed
     */
    public function show($id)
    {
        return Gene::findOrFail($id);
    }
}
