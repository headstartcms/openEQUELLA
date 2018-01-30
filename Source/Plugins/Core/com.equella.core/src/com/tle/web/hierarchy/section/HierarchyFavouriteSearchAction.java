/*
 * Copyright 2017 Apereo
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.tle.web.hierarchy.section;

import javax.inject.Inject;

import com.tle.web.search.actions.AbstractFavouriteSearchAction;
import com.tle.web.sections.equella.dialog.EquellaDialog;
import com.tle.web.sections.standard.annotations.Component;

public class HierarchyFavouriteSearchAction extends AbstractFavouriteSearchAction
{
	@Inject
	@Component(name = "fd")
	private HierarchyFavouriteSearchDialog dialog;

	@Override
	protected EquellaDialog<?> getDialog()
	{
		return dialog;
	}
}