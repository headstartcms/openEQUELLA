/*
 * Licensed to The Apereo Foundation under one or more contributor license
 * agreements. See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 *
 * The Apereo Foundation licenses this file to you under the Apache License,
 * Version 2.0, (the "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at:
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.tle.core.institution.impl;

import com.tle.beans.Institution;
import com.tle.core.guice.Bind;
import com.tle.core.hibernate.dao.GenericDaoImpl;
import com.tle.core.institution.InstitutionDao;
import javax.inject.Singleton;
import org.hibernate.criterion.Restrictions;

@Singleton
@SuppressWarnings("nls")
@Bind(InstitutionDao.class)
public class InstitutionDaoImpl extends GenericDaoImpl<Institution, Long>
    implements InstitutionDao {
  public InstitutionDaoImpl() {
    super(Institution.class);
  }

  @Override
  public Institution findByUniqueId(long uniqueId) {
    return findByCriteria(Restrictions.eq("uniqueId", uniqueId));
  }
}
